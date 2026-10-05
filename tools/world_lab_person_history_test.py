"""Full authored-world validation of person history and period boundaries."""
import copy
import unittest
import world_lab as Lab


def authored():
    world = Lab.load(Lab.ROOT / "tools/world_lab/definition.example.json")
    world["sandbox"].update({"SurvivorAwareness.Population": 2, "SurvivorAwareness.Newcomers": 2,
                             "StartMonth": 1, "StartDay": 1})
    world["observation"]["sites"] = [dict(id="home", label="Home", x=128, y=128, z=0)]
    event = dict(id="shared-movie", occurredOn="1992-12-24", acquiredOn="1992-12-24",
                 participants=["prior-loved-one"], subject="cinema", action="watched",
                 description="A shared movie before the start of this world.", valence=.7, salience=.8,
                 sourceId="authored-life", sourceSha256="a" * 64, provenance="authored-synthetic",
                 relations=[{"from": "cinema", "relation": "may-contain", "into": "seat", "confidence": .7}])
    world["situation"] = dict(initialPeopleBySite={"home": 2}, initialLifeHistory=[
        dict(siteId="home", actorOrdinal=1, startDate="1993-01-01", birthYear=1960, episodes=[event]),
        dict(siteId="home", actorOrdinal=2, startDate="1993-01-01", birthYear=1980, episodes=[])])
    return world


class PersonHistory(unittest.TestCase):
    def test_general_history_and_explicit_empty_are_detached_by_validation(self):
        world = authored()
        before = copy.deepcopy(world)
        self.assertIs(Lab.validate(world), world)
        self.assertEqual(before, world)

    def test_cutoff_moves_with_start_not_official_outbreak(self):
        world = authored()
        event = world["situation"]["initialLifeHistory"][0]["episodes"][0]
        event.update(occurredOn="1993-03-01", acquiredOn="1993-03-01")
        with self.assertRaisesRegex(ValueError, "chronology"):
            Lab.validate(world)
        world["sandbox"].update(StartMonth=7, StartDay=9)
        for row in world["situation"]["initialLifeHistory"]:
            row["startDate"] = "1993-07-09"
        Lab.validate(world)

    def test_earlier_pre1994_and_leap_calendar(self):
        world = authored()
        world["sandbox"].update(StartMonth=2, StartDay=29)
        for row in world["situation"]["initialLifeHistory"]:
            row["startDate"] = "1992-02-29"
            for event in row["episodes"]:
                event.update(occurredOn="1991-12-24", acquiredOn="1991-12-24")
        Lab.validate(world)
        for row in world["situation"]["initialLifeHistory"]:
            row["startDate"] = "1993-02-29"
        with self.assertRaisesRegex(ValueError, "date"):
            Lab.validate(world)

    def test_admission_identity_and_future_inputs_refused(self):
        mutations = {
            "unstaged": lambda s: s.pop("initialPeopleBySite"),
            "foreign-site": lambda s: s["initialLifeHistory"][0].update(siteId="elsewhere"),
            "boolean-ordinal": lambda s: s["initialLifeHistory"][0].update(actorOrdinal=True),
            "wrong-ordinal": lambda s: s["initialLifeHistory"][0].update(actorOrdinal=3),
            "duplicate-person": lambda s: s["initialLifeHistory"].append(copy.deepcopy(s["initialLifeHistory"][0])),
            "post1993": lambda s: s["initialLifeHistory"][0].update(startDate="1994-01-01"),
            "birth-future": lambda s: s["initialLifeHistory"][0].update(birthYear=1994),
            "different-starts": lambda s: s["initialLifeHistory"][0].update(startDate="1992-01-01"),
            "episodes-object": lambda s: s["initialLifeHistory"][0].update(episodes={}),
            "authored-owner": lambda s: s["initialLifeHistory"][0]["episodes"][0].update(ownerId="someone"),
        }
        for label, mutate in mutations.items():
            with self.subTest(label=label):
                world = authored()
                mutate(world["situation"])
                with self.assertRaises(ValueError):
                    Lab.validate(world)

    def test_episode_semantics_and_sources_refused(self):
        mutations = [dict(occurredOn="1959-01-01"), dict(acquiredOn="1992-12-23"),
                     dict(acquiredOn="1993-01-02"), dict(sourceSha256="wrong"), dict(provenance="verified"),
                     dict(salience=True), dict(salience=float("nan")), dict(valence=2),
                     dict(participants=["same", "same"]), dict(participants={}),
                     dict(description="bad\nsource"), dict(relations={}),
                     dict(relations=[{"from": "cinema", "relation": [], "into": "seat", "confidence": .7}])]
        for change in mutations:
            with self.subTest(change=change):
                world = authored()
                world["situation"]["initialLifeHistory"][0]["episodes"][0].update(change)
                with self.assertRaises(ValueError):
                    Lab.validate(world)

    def test_unicode_native_string_limits_and_invalid_surrogates(self):
        world = authored()
        event = world["situation"]["initialLifeHistory"][0]["episodes"][0]
        event["description"] = "\U0001f3ac" * 1024
        Lab.validate(world)
        for description in ("\U0001f3ac" * 1025, "\ud800"):
            event["description"] = description
            with self.assertRaises(ValueError):
                Lab.validate(world)

    def test_calendar_and_dense_bounds_refused(self):
        world = authored()
        world["sandbox"]["StartMonth"] = 7
        with self.assertRaisesRegex(ValueError, "sandbox date"):
            Lab.validate(world)
        world = authored()
        row = world["situation"]["initialLifeHistory"][0]
        row["episodes"] = [dict(row["episodes"][0], id=f"event-{i}") for i in range(65)]
        with self.assertRaisesRegex(ValueError, "64 episodes"):
            Lab.validate(world)


if __name__ == "__main__":
    unittest.main()
