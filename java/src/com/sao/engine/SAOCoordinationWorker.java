package com.sao.engine;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.FutureTask;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

/**
 * One bounded daemon worker for non-authoritative coordination inference.
 * Requests are immutable Java values.  Results are only returned to the Lua
 * owner, which revalidates the process, response revision, options and current
 * registered execution owner before retaining a shadow observation.
 */
public final class SAOCoordinationWorker {
    public static final String EXPECTED_BUNDLE_SHA256 =
        "02edcdc1caf7489f0871f63e35af2c2cc26966ec74c0cf30eb63d155b1acb33c";
    public static final String RESOURCE =
        "/com/sao/model/coordination-r67.bundle";
    private static final int MAX_PENDING = 128;
    private static final int MAX_QUEUE = 64;
    private static final int MAX_INPUT_CHARS = 65_536;

    private record Outcome(SAOCoordinationModel.Result result, String inputSha256,
                           long latencyNanos) { }

    private final SAOCoordinationModel model;
    private final String loadFailure;
    private final ThreadPoolExecutor executor;
    private final Map<String, FutureTask<Outcome>> pending =
        new ConcurrentHashMap<>();

    public SAOCoordinationWorker() {
        SAOCoordinationModel loaded = null;
        String failure = null;
        try (InputStream input = SAOCoordinationWorker.class.getResourceAsStream(
                RESOURCE)) {
            if (input == null) {
                throw new IOException("bundle resource is absent");
            }
            loaded = SAOCoordinationModel.load(readBounded(input, 1_048_576),
                EXPECTED_BUNDLE_SHA256);
        } catch (Throwable throwable) {
            failure = safeReason(throwable);
        }
        this.model = loaded;
        this.loadFailure = failure;
        ThreadFactory threads = runnable -> {
            Thread thread = new Thread(runnable, "SAO-coordination-shadow");
            thread.setDaemon(true);
            thread.setPriority(Thread.MIN_PRIORITY);
            return thread;
        };
        this.executor = new ThreadPoolExecutor(1, 1, 0L, TimeUnit.MILLISECONDS,
            new ArrayBlockingQueue<>(MAX_QUEUE), threads,
            new ThreadPoolExecutor.AbortPolicy());
    }

    public String status() {
        if (model == null) {
            return "REFUSED\t" + safeField(loadFailure);
        }
        return "READY\t" + model.bundleSha256() + "\t" + model.bundleId()
            + "\t" + model.modelSha256() + "\t" + model.estimatedBytes();
    }

    public synchronized String submit(String requestId, String canonicalJson,
            String featuresCsv, String optionsCsv) {
        if (model == null) {
            return "REFUSED\tbundle-unavailable";
        }
        if (!validRequestId(requestId)) {
            return "REFUSED\tinvalid-request-id";
        }
        if (canonicalJson == null || canonicalJson.isEmpty()
                || canonicalJson.length() > MAX_INPUT_CHARS) {
            return "REFUSED\tinvalid-input-length";
        }
        if (pending.size() >= MAX_PENDING) {
            return "REFUSED\tpending-capacity";
        }
        if (pending.containsKey(requestId)) {
            return "REFUSED\tduplicate-request-id";
        }
        final float[] features;
        final List<String> options;
        final String inputSha256;
        try {
            features = parseFeatures(featuresCsv, model.featureNames().size());
            options = parseOptions(optionsCsv, model.labels());
            inputSha256 = SAOCoordinationModel.sha256(
                canonicalJson.getBytes(StandardCharsets.UTF_8));
        } catch (Throwable throwable) {
            return "REFUSED\t" + safeReason(throwable);
        }
        final String immutableInput = canonicalJson;
        final List<String> immutableOptions = List.copyOf(options);
        FutureTask<Outcome> task = new FutureTask<>(() -> {
            long started = System.nanoTime();
            SAOCoordinationModel.Result result = model.infer(immutableInput,
                features, immutableOptions);
            return new Outcome(result, inputSha256,
                System.nanoTime() - started);
        });
        pending.put(requestId, task);
        try {
            executor.execute(task);
            return "QUEUED\t" + requestId + "\t" + inputSha256;
        } catch (Throwable throwable) {
            pending.remove(requestId, task);
            task.cancel(true);
            return "REFUSED\tworker-capacity";
        }
    }

    public String poll(String requestId) {
        if (!validRequestId(requestId)) {
            return "REFUSED\tinvalid-request-id";
        }
        FutureTask<Outcome> task = pending.get(requestId);
        if (task == null) {
            return "MISSING";
        }
        if (!task.isDone()) {
            return "PENDING";
        }
        if (!pending.remove(requestId, task)) {
            return "MISSING";
        }
        try {
            Outcome outcome = task.get();
            StringBuilder probabilities = new StringBuilder();
            for (String label : model.labels()) {
                Float value = outcome.result().probabilities().get(label);
                if (value == null) {
                    continue;
                }
                if (probabilities.length() > 0) {
                    probabilities.append(',');
                }
                probabilities.append(label.replace(',', '-').replace('=', '-'))
                    .append('=').append(value);
            }
            return "READY\t" + model.bundleSha256() + "\t"
                + outcome.inputSha256() + "\t" + outcome.result().response()
                + "\t" + probabilities + "\t"
                + outcome.result().tokenIds().length + "\t"
                + outcome.latencyNanos();
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            return "FAILED\tinterrupted";
        } catch (ExecutionException exception) {
            return "FAILED\t" + safeReason(exception.getCause());
        }
    }

    public synchronized String cancel(String requestId) {
        if (!validRequestId(requestId)) {
            return "REFUSED\tinvalid-request-id";
        }
        FutureTask<Outcome> task = pending.remove(requestId);
        if (task == null) {
            return "MISSING";
        }
        executor.remove(task);
        task.cancel(true);
        return "CANCELLED\t" + requestId;
    }

    public synchronized void resetRuntimeForWorld() {
        for (FutureTask<Outcome> task : pending.values()) {
            task.cancel(true);
        }
        pending.clear();
        executor.getQueue().clear();
    }

    public int pendingCount() {
        return pending.size();
    }

    private static float[] parseFeatures(String csv, int expected) {
        String[] fields = csv == null ? new String[0] : csv.split(",", -1);
        if (fields.length != expected) {
            throw new IllegalArgumentException("typed-feature-width");
        }
        float[] result = new float[expected];
        for (int index = 0; index < expected; index++) {
            result[index] = Float.parseFloat(fields[index]);
            if (!Float.isFinite(result[index])) {
                throw new IllegalArgumentException("typed-feature-nonfinite");
            }
        }
        return result;
    }

    private static List<String> parseOptions(String csv, List<String> labels) {
        String[] fields = csv == null ? new String[0] : csv.split(",", -1);
        if (fields.length == 0 || fields.length > labels.size()) {
            throw new IllegalArgumentException("feasible-options-count");
        }
        Set<String> unique = new LinkedHashSet<>();
        for (String field : fields) {
            if (!labels.contains(field) || !unique.add(field)) {
                throw new IllegalArgumentException("feasible-option-invalid");
            }
        }
        return List.copyOf(unique);
    }

    private static boolean validRequestId(String value) {
        return value != null && value.length() >= 1 && value.length() <= 240
            && value.matches("[A-Za-z0-9._:/-]+");
    }

    private static byte[] readBounded(InputStream input, int maximum)
            throws IOException {
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        byte[] buffer = new byte[8192];
        int count;
        while ((count = input.read(buffer)) != -1) {
            if (output.size() + count > maximum) {
                throw new IOException("bundle resource exceeds its bound");
            }
            output.write(buffer, 0, count);
        }
        return output.toByteArray();
    }

    private static String safeReason(Throwable throwable) {
        if (throwable == null) {
            return "unknown";
        }
        String value = throwable.getMessage();
        if (value == null || value.isBlank()) {
            value = throwable.getClass().getSimpleName();
        }
        return safeField(value).replace(' ', '-');
    }

    private static String safeField(String value) {
        if (value == null) {
            return "unknown";
        }
        return value.replace('\t', '-').replace('\r', '-').replace('\n', '-');
    }
}
