import json
import sqlite3
import tempfile
import unittest
from pathlib import Path
from proxy import validate, responses_payload, extract_result, record_event

class ProxyTests(unittest.TestCase):
    def plan(self):
        return {"message": "Validate demand before building.", "quests": [{"title": "Speak with one buyer", "details": "Record the costly workflow.", "domain": "business", "priority": "main", "minutes": 30}]}
    def test_response_format_and_privacy(self):
        payload = responses_payload("dailyPlan", {"goal": "Business"}, "configured-model")
        self.assertFalse(payload["store"])
        self.assertEqual(payload["text"]["format"]["type"], "json_schema")
        self.assertTrue(payload["text"]["format"]["strict"])
        with self.assertRaises(ValueError): responses_payload("dailyPlan", {"entireDatabase": []}, "model")
    def test_valid_and_corrupt_output(self):
        response = {"status": "completed", "output": [{"content": [{"type": "output_text", "text": json.dumps(self.plan())}]}]}
        self.assertEqual(extract_result(response), self.plan())
        with self.assertRaises(ValueError): extract_result({"status": "incomplete"})
        invalid = self.plan(); invalid["quests"][0]["coins"] = 999
        with self.assertRaises(ValueError): validate(invalid)
        invalid = self.plan(); invalid["quests"] *= 4
        with self.assertRaises(ValueError): validate(invalid)
    def test_n8n_deduplication_no_rewards(self):
        with tempfile.TemporaryDirectory() as directory:
            db = str(Path(directory) / "events.sqlite")
            event = {"id": "abc", "kind": "automation_deployed", "project": "CRM", "timestamp": "2026-10-07T00:00:00Z"}
            self.assertEqual(record_event(event, db)["rewards"], "none")
            record_event(event, db)
            with sqlite3.connect(db) as connection: self.assertEqual(connection.execute("SELECT COUNT(*) FROM events").fetchone()[0], 1)

if __name__ == "__main__": unittest.main()
