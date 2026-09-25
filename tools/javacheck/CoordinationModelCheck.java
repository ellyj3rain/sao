import com.sao.engine.SAOCoordinationModel;
import com.sao.engine.SAOCoordinationWorker;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Headless execution of the exact native evaluator and async worker. */
public final class CoordinationModelCheck {
    private record Vector(String rowId, byte[] input, int[] tokens,
                          float[] features, List<String> options,
                          String predicted, Map<String, Float> probabilities) { }

    private static void require(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }

    private static int[] integers(String value) {
        if (value.isEmpty()) return new int[0];
        String[] fields = value.split(",", -1);
        int[] result = new int[fields.length];
        for (int index = 0; index < fields.length; index++) {
            result[index] = Integer.parseInt(fields[index]);
        }
        return result;
    }

    private static float[] floats(String value) {
        String[] fields = value.split(",", -1);
        float[] result = new float[fields.length];
        for (int index = 0; index < fields.length; index++) {
            result[index] = Float.parseFloat(fields[index]);
        }
        return result;
    }

    private static Map<String, Float> probabilities(String value) {
        Map<String, Float> result = new LinkedHashMap<>();
        for (String field : value.split(",", -1)) {
            String[] pair = field.split("=", 2);
            require(pair.length == 2, "probability vector is malformed");
            result.put(pair[0], Float.parseFloat(pair[1]));
        }
        return result;
    }

    private static List<Vector> vectors(Path path) throws Exception {
        List<String> lines = Files.readAllLines(path, StandardCharsets.UTF_8);
        require(lines.size() == 21, "parity row count differs");
        require(lines.get(0).equals(
            "rowId\tinputBase64\ttokenIds\tfeatures\tallowed\tpredicted\tprobabilities"),
            "parity header differs");
        List<Vector> result = new ArrayList<>();
        for (int line = 1; line < lines.size(); line++) {
            String[] fields = lines.get(line).split("\t", -1);
            require(fields.length == 7, "parity field count differs");
            result.add(new Vector(fields[0], Base64.getDecoder().decode(fields[1]),
                integers(fields[2]), floats(fields[3]),
                List.of(fields[4].split(",", -1)), fields[5],
                probabilities(fields[6])));
        }
        return result;
    }

    private static byte[] hex(String value) {
        require(value.length() % 2 == 0, "hex byte vector has odd width");
        byte[] result = new byte[value.length() / 2];
        for (int index = 0; index < result.length; index++) {
            result[index] = (byte) Integer.parseInt(
                value.substring(index * 2, index * 2 + 2), 16);
        }
        return result;
    }

    private static int tokenizerCases(SAOCoordinationModel model, Path path)
            throws Exception {
        List<String> lines = Files.readAllLines(path, StandardCharsets.US_ASCII);
        require(lines.get(0).equals("name\tbytesHex\ttokenIds"),
            "tokenizer-vector header differs");
        for (int line = 1; line < lines.size(); line++) {
            String[] fields = lines.get(line).split("\t", -1);
            require(fields.length == 3, "tokenizer-vector field count differs");
            require(Arrays.equals(model.tokenizeBytes(hex(fields[1])),
                                  integers(fields[2])),
                "tokenizer parity differs for " + fields[0]);
        }
        return lines.size() - 1;
    }

    private static String csv(float[] values) {
        StringBuilder result = new StringBuilder();
        for (float value : values) {
            if (result.length() > 0) result.append(',');
            result.append(value);
        }
        return result.toString();
    }

    private static String await(SAOCoordinationWorker worker, String id)
            throws Exception {
        long deadline = System.nanoTime() + 2_000_000_000L;
        while (System.nanoTime() < deadline) {
            String result = worker.poll(id);
            if (!result.equals("PENDING")) return result;
            Thread.onSpinWait();
        }
        throw new AssertionError("async coordination result timed out");
    }

    private static long percentile(long[] values, double fraction) {
        long[] copy = values.clone();
        Arrays.sort(copy);
        return copy[Math.min(copy.length - 1,
            (int) Math.floor((copy.length - 1) * fraction))];
    }

    public static void main(String[] args) throws Exception {
        require(args.length == 3, "bundle, parity and tokenizer vectors required");
        byte[] bundle = Files.readAllBytes(Path.of(args[0]));
        SAOCoordinationModel model = SAOCoordinationModel.load(bundle,
            SAOCoordinationWorker.EXPECTED_BUNDLE_SHA256);
        List<Vector> vectors = vectors(Path.of(args[1]));
        int tokenizerCases = tokenizerCases(model, Path.of(args[2]));
        float maximumDelta = 0.0f;
        for (Vector vector : vectors) {
            require(Arrays.equals(model.tokenizeInput(vector.input()), vector.tokens()),
                "input token parity differs for " + vector.rowId());
            SAOCoordinationModel.Result result = model.infer(vector.input(),
                vector.features(), vector.options());
            require(result.response().equals(vector.predicted()),
                "prediction differs for " + vector.rowId());
            require(result.probabilities().keySet().equals(
                    vector.probabilities().keySet()),
                "probability mask differs for " + vector.rowId());
            for (Map.Entry<String, Float> entry : vector.probabilities().entrySet()) {
                maximumDelta = Math.max(maximumDelta, Math.abs(
                    result.probabilities().get(entry.getKey()) - entry.getValue()));
            }
        }
        require(maximumDelta <= 1.0e-6f, "numeric parity exceeds tolerance");

        byte[] corrupt = bundle.clone();
        corrupt[corrupt.length - 1] ^= 1;
        try {
            SAOCoordinationModel.load(corrupt,
                SAOCoordinationWorker.EXPECTED_BUNDLE_SHA256);
            throw new AssertionError("corrupt bundle was accepted");
        } catch (java.io.IOException expected) {
            require(expected.getMessage().contains("SHA-256"),
                "corrupt bundle refused for the wrong reason");
        }
        Vector first = vectors.get(0);
        try {
            model.infer(first.input(), new float[15], first.options());
            throw new AssertionError("wrong feature width was accepted");
        } catch (IllegalArgumentException expected) {
            require(expected.getMessage().contains("width"),
                "wrong feature width refused for the wrong reason");
        }
        try {
            model.infer(first.input(), first.features(), List.of("decline"));
            throw new AssertionError("unsupported-only mask was accepted");
        } catch (IllegalArgumentException expected) {
            require(expected.getMessage().contains("no learned"),
                "unsupported mask refused for the wrong reason");
        }

        // Measure the exact evaluator after warm-up.
        for (int pass = 0; pass < 20; pass++) {
            for (Vector vector : vectors) {
                model.infer(vector.input(), vector.features(), vector.options());
            }
        }
        long[] inferenceNanos = new long[2_000];
        for (int index = 0; index < inferenceNanos.length; index++) {
            Vector vector = vectors.get(index % vectors.size());
            long started = System.nanoTime();
            model.infer(vector.input(), vector.features(), vector.options());
            inferenceNanos[index] = System.nanoTime() - started;
        }

        // Exercise the same one-thread resource loader and wire used by Lua.
        SAOCoordinationWorker worker = new SAOCoordinationWorker();
        require(worker.status().startsWith("READY\t" +
                SAOCoordinationWorker.EXPECTED_BUNDLE_SHA256 + "\t"),
            "async worker did not load the exact bundle: " + worker.status());
        String queued = worker.submit("control/one",
            new String(first.input(), StandardCharsets.UTF_8),
            csv(first.features()), String.join(",", first.options()));
        require(queued.startsWith("QUEUED\tcontrol/one\t"),
            "async worker refused a valid snapshot: " + queued);
        require(worker.submit("control/one",
            new String(first.input(), StandardCharsets.UTF_8),
            csv(first.features()), String.join(",", first.options()))
                .equals("REFUSED\tduplicate-request-id"),
            "async worker accepted a duplicate request");
        String completed = await(worker, "control/one");
        require(completed.startsWith("READY\t" + model.bundleSha256() + "\t")
                && completed.contains("\t" + first.predicted() + "\t"),
            "async worker result differs: " + completed);
        require(worker.submit("bad/features",
            new String(first.input(), StandardCharsets.UTF_8), "0,1",
            String.join(",", first.options())).startsWith("REFUSED\t"),
            "async worker accepted malformed features");
        require(worker.submit("control/cancel",
            new String(first.input(), StandardCharsets.UTF_8),
            csv(first.features()), String.join(",", first.options()))
                .startsWith("QUEUED\t"), "cancel control did not queue");
        require(worker.cancel("control/cancel").equals(
                "CANCELLED\tcontrol/cancel")
                && worker.poll("control/cancel").equals("MISSING"),
            "one-request cancellation retained an async task");

        long[] roundTripNanos = new long[100];
        for (int index = 0; index < roundTripNanos.length; index++) {
            Vector vector = vectors.get(index % vectors.size());
            String id = "measure/" + index;
            long started = System.nanoTime();
            require(worker.submit(id,
                new String(vector.input(), StandardCharsets.UTF_8),
                csv(vector.features()), String.join(",", vector.options()))
                    .startsWith("QUEUED\t"),
                "async measurement submission failed");
            require(await(worker, id).startsWith("READY\t"),
                "async measurement completion failed");
            roundTripNanos[index] = System.nanoTime() - started;
        }
        require(worker.submit("control/reset",
            new String(first.input(), StandardCharsets.UTF_8),
            csv(first.features()), String.join(",", first.options()))
                .startsWith("QUEUED\t"), "reset control did not queue");
        worker.resetRuntimeForWorld();
        require(worker.poll("control/reset").equals("MISSING")
                && worker.pendingCount() == 0,
            "world reset retained an async request");

        // Keep one evaluator occupied long enough to fill either the bounded
        // executor queue or the stricter pending map. A missing bound would
        // admit every request and make this control fail.
        SAOCoordinationWorker bounded = new SAOCoordinationWorker();
        String largeInput = "{\"padding\":\"" + "x".repeat(60_000) + "\"}";
        int boundedAccepted = 0;
        String capacityRefusal = null;
        for (int index = 0; index < 140; index++) {
            String admission = bounded.submit("capacity/" + index, largeInput,
                csv(first.features()), String.join(",", first.options()));
            if (admission.startsWith("QUEUED\t")) {
                boundedAccepted++;
            } else {
                capacityRefusal = admission;
                break;
            }
        }
        require(boundedAccepted > 0 && boundedAccepted <= 128,
            "async worker admission was not bounded");
        require("REFUSED\tworker-capacity".equals(capacityRefusal)
                || "REFUSED\tpending-capacity".equals(capacityRefusal),
            "async worker did not expose its capacity bound: " + capacityRefusal);
        bounded.resetRuntimeForWorld();
        require(bounded.pendingCount() == 0,
            "capacity-control reset retained requests");

        long inferenceTotal = 0;
        for (long value : inferenceNanos) inferenceTotal += value;
        long roundTripTotal = 0;
        for (long value : roundTripNanos) roundTripTotal += value;
        System.out.println("PASS rows=" + vectors.size()
            + " tokenizerCases=" + tokenizerCases
            + " maxProbabilityDelta=" + maximumDelta
            + " evaluatorMeanUs=" + (inferenceTotal / inferenceNanos.length / 1000.0)
            + " evaluatorP95Us=" + (percentile(inferenceNanos, .95) / 1000.0)
            + " asyncMeanUs=" + (roundTripTotal / roundTripNanos.length / 1000.0)
            + " asyncP95Us=" + (percentile(roundTripNanos, .95) / 1000.0)
            + " boundedAccepted=" + boundedAccepted
            + " modelBytes=" + model.estimatedBytes()
            + " bundleBytes=" + bundle.length);
    }
}
