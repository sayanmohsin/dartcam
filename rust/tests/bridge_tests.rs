use std::sync::Mutex;

use thingd::{
    AggregateFunction, AggregateOptions, AggregateStore, EventLog, Link, LinkDirection,
    LinkQueryOptions, LinkStore, ListEventsOptions, MemoryEvent, MemoryObject, ObjectStore,
    QueueClaimOptions, QueueJob, QueueNackOptions, QueueStore, SearchOptions, Searcher,
    SqliteThingStore, TimeBucket, TimeSeriesOptions,
};

fn open_store() -> Mutex<SqliteThingStore> {
    Mutex::new(SqliteThingStore::open_in_memory().unwrap())
}

// ── Object Store Tests ────────────────────────────────────────────────

#[test]
fn test_put_and_get_object() {
    let store = open_store();
    let obj = MemoryObject::new("players", "p1", r#"{"name":"Alice"}"#);
    store.lock().unwrap().put_object(obj).unwrap();

    let result = store
        .lock()
        .unwrap()
        .get_object("players", "p1")
        .unwrap();
    assert!(result.is_some());
    assert_eq!(result.unwrap().body, r#"{"name":"Alice"}"#);
}

#[test]
fn test_get_object_not_found() {
    let store = open_store();
    let result = store.lock().unwrap().get_object("players", "nonexistent").unwrap();
    assert!(result.is_none());
}

#[test]
fn test_put_objects_batch() {
    let store = open_store();
    let items = vec![
        MemoryObject::new("players", "p1", r#"{"name":"Alice"}"#),
        MemoryObject::new("players", "p2", r#"{"name":"Bob"}"#),
    ];
    store.lock().unwrap().put_objects_batch(items).unwrap();

    let p1 = store.lock().unwrap().get_object("players", "p1").unwrap();
    let p2 = store.lock().unwrap().get_object("players", "p2").unwrap();
    assert!(p1.is_some());
    assert!(p2.is_some());
}

#[test]
fn test_delete_object() {
    let store = open_store();
    store
        .lock()
        .unwrap()
        .put_object(MemoryObject::new("players", "p1", "{}"))
        .unwrap();
    let deleted = store.lock().unwrap().delete_object("players", "p1").unwrap();
    assert!(deleted);
    let result = store.lock().unwrap().get_object("players", "p1").unwrap();
    assert!(result.is_none());
}

#[test]
fn test_delete_objects_batch() {
    let store = open_store();
    store
        .lock()
        .unwrap()
        .put_object(MemoryObject::new("players", "p1", "{}"))
        .unwrap();
    store
        .lock()
        .unwrap()
        .put_object(MemoryObject::new("players", "p2", "{}"))
        .unwrap();
    let keys = vec![
        ("players".to_string(), "p1".to_string()),
        ("players".to_string(), "p2".to_string()),
    ];
    let count = store.lock().unwrap().delete_objects_batch(&keys).unwrap();
    assert_eq!(count, 2);
}

#[test]
fn test_list_objects() {
    let store = open_store();
    store
        .lock()
        .unwrap()
        .put_object(MemoryObject::new("players", "p1", "{}"))
        .unwrap();
    store
        .lock()
        .unwrap()
        .put_object(MemoryObject::new("players", "p2", "{}"))
        .unwrap();
    let objects = store
        .lock()
        .unwrap()
        .list_objects(Some(&["players".to_string()]), &Default::default())
        .unwrap();
    assert_eq!(objects.len(), 2);
}

// ── Event Log Tests ───────────────────────────────────────────────────

#[test]
fn test_append_and_list_events() {
    let store = open_store();
    let event = MemoryEvent::new("match_123", "turn.recorded", r#"{"score":60}"#);
    store.lock().unwrap().append_event(event).unwrap();

    let events = store
        .lock()
        .unwrap()
        .list_events(Some("match_123"), ListEventsOptions::default())
        .unwrap();
    assert_eq!(events.len(), 1);
    assert_eq!(events[0].body, r#"{"score":60}"#);
}

#[test]
fn test_append_events_batch() {
    let store = open_store();
    let events = vec![
        MemoryEvent::new("match_123", "turn.recorded", r#"{"score":60}"#),
        MemoryEvent::new("match_123", "turn.recorded", r#"{"score":40}"#),
    ];
    store.lock().unwrap().append_events_batch(events).unwrap();

    let listed = store
        .lock()
        .unwrap()
        .list_events(Some("match_123"), ListEventsOptions::default())
        .unwrap();
    assert_eq!(listed.len(), 2);
}

#[test]
fn test_list_events_from_sequence() {
    let store = open_store();
    for i in 0..5 {
        let event = MemoryEvent::new("match_123", "turn", &format!(r#"{{"i":{i}}}"#));
        store.lock().unwrap().append_event(event).unwrap();
    }

    let options = ListEventsOptions {
        from_sequence: Some(2),
        limit: None,
    };
    let events = store
        .lock()
        .unwrap()
        .list_events(Some("match_123"), options)
        .unwrap();
    assert_eq!(events.len(), 3); // sequences 3, 4, 5 (0-indexed but from_sequence is exclusive)
    assert_eq!(events[0].body, r#"{"i":2}"#);
}

#[test]
fn test_delete_last_event() {
    let store = open_store();
    for i in 0..3 {
        let event = MemoryEvent::new("match_123", "turn", &format!(r#"{{"i":{i}}}"#));
        store.lock().unwrap().append_event(event).unwrap();
    }

    let deleted = store.lock().unwrap().delete_last_event("match_123").unwrap();
    assert!(deleted.is_some());

    let events = store
        .lock()
        .unwrap()
        .list_events(Some("match_123"), ListEventsOptions::default())
        .unwrap();
    assert_eq!(events.len(), 2);
}

#[test]
fn test_delete_stream() {
    let store = open_store();
    for _ in 0..3 {
        store
            .lock()
            .unwrap()
            .append_event(MemoryEvent::new("match_123", "turn", "{}"))
            .unwrap();
    }

    let count = store.lock().unwrap().delete_stream("match_123").unwrap();
    assert_eq!(count, 3);

    let events = store
        .lock()
        .unwrap()
        .list_events(Some("match_123"), ListEventsOptions::default())
        .unwrap();
    assert_eq!(events.len(), 0);
}

// ── Search Tests ──────────────────────────────────────────────────────

#[test]
fn test_search_finds_matching_objects() {
    let store = open_store();
    store
        .lock()
        .unwrap()
        .put_object(MemoryObject::new("docs", "readme", "Getting started guide for thingd"))
        .unwrap();
    store
        .lock()
        .unwrap()
        .put_object(MemoryObject::new("docs", "api", "API reference documentation"))
        .unwrap();

    let results = store
        .lock()
        .unwrap()
        .search("getting started", SearchOptions::default())
        .unwrap();
    assert!(!results.is_empty());
}

#[test]
fn test_search_with_collection_filter() {
    let store = open_store();
    store
        .lock()
        .unwrap()
        .put_object(MemoryObject::new("docs", "readme", "Getting started guide"))
        .unwrap();
    store
        .lock()
        .unwrap()
        .put_object(MemoryObject::new("notes", "note1", "Getting started notes"))
        .unwrap();

    let options = SearchOptions {
        collections: Some(vec!["docs".to_string()]),
        ..SearchOptions::default()
    };
    let results = store
        .lock()
        .unwrap()
        .search("getting started", options)
        .unwrap();
    assert_eq!(results.len(), 1);
    assert_eq!(results[0].collection, "docs");
}

// ── Aggregate Tests ───────────────────────────────────────────────────

#[test]
fn test_aggregate_count_with_group_by() {
    let store = open_store();
    for (id, region) in [("s1", "North"), ("s2", "North"), ("s3", "South")] {
        store
            .lock()
            .unwrap()
            .put_object(MemoryObject::new(
                "sales",
                id,
                &format!(r#"{{"region":"{region}","amount":100}}"#),
            ))
            .unwrap();
    }

    let options = AggregateOptions {
        function: AggregateFunction::Count,
        group_by: Some("region".to_string()),
        ..AggregateOptions::default()
    };
    let result = store.lock().unwrap().aggregate("sales", &options).unwrap();
    assert_eq!(result.total, 3.0);
    assert_eq!(result.groups.len(), 2);
    let north = result.groups.iter().find(|g| g.key == "North").unwrap();
    assert_eq!(north.value, 2.0);
}

#[test]
fn test_aggregate_sum() {
    let store = open_store();
    for (id, amount) in [("s1", 100), ("s2", 200), ("s3", 300)] {
        store
            .lock()
            .unwrap()
            .put_object(MemoryObject::new(
                "sales",
                id,
                &format!(r#"{{"amount":{amount}}}"#),
            ))
            .unwrap();
    }

    let options = AggregateOptions {
        function: AggregateFunction::Sum,
        field: Some("amount".to_string()),
        ..AggregateOptions::default()
    };
    let result = store.lock().unwrap().aggregate("sales", &options).unwrap();
    assert_eq!(result.total, 600.0);
}

// ── Queue Tests ────────────────────────────────────────────────────────

#[test]
fn test_push_and_claim_job() {
    let mut store = open_store();
    let job = QueueJob::new("vision", "job-1", r#"{"imagePath":"/tmp/shot.png"}"#, 3);
    store.lock().unwrap().push_job(job).unwrap();

    let claimed = store.lock().unwrap().claim_job("vision").unwrap();
    assert!(claimed.is_some());
    let claimed = claimed.unwrap();
    assert_eq!(claimed.body, r#"{"imagePath":"/tmp/shot.png"}"#);
}

#[test]
fn test_ack_job() {
    let mut store = open_store();
    let job = QueueJob::new("vision", "job-1", r#"{}"#, 3);
    store.lock().unwrap().push_job(job).unwrap();

    let claimed = store.lock().unwrap().claim_job("vision").unwrap().unwrap();
    let acked = store.lock().unwrap().ack_job("vision", &claimed.id).unwrap();
    assert!(acked.is_some());
    assert_eq!(acked.unwrap().status, thingd::QueueJobStatus::Completed);
}

#[test]
fn test_nack_job_retries() {
    let mut store = open_store();
    let job = QueueJob::new("vision", "job-1", r#"{}"#, 3);
    store.lock().unwrap().push_job(job).unwrap();

    let claimed = store.lock().unwrap().claim_job("vision").unwrap().unwrap();
    store
        .lock()
        .unwrap()
        .nack_job("vision", &claimed.id)
        .unwrap();

    // Job should be available again for re-claim (attempts incremented)
    let reclaimed = store.lock().unwrap().claim_job("vision").unwrap();
    assert!(reclaimed.is_some());
    // After push(0) → claim(0) → nack(1) → claim(1), attempts should be >= 1
    assert!(reclaimed.unwrap().attempts >= 1);
}

#[test]
fn test_list_dead_jobs() {
    let mut store = open_store();
    // Push job with 1 max attempt, so nack moves it to dead
    let job = QueueJob::new("vision", "job-1", r#"{}"#, 1);
    store.lock().unwrap().push_job(job).unwrap();

    let claimed = store.lock().unwrap().claim_job("vision").unwrap().unwrap();
    store
        .lock()
        .unwrap()
        .nack_job("vision", &claimed.id)
        .unwrap();

    let dead = store.lock().unwrap().list_dead_jobs("vision").unwrap();
    assert_eq!(dead.len(), 1);
}

#[test]
fn test_list_jobs() {
    let store = open_store();
    store
        .lock()
        .unwrap()
        .push_job(QueueJob::new("vision", "job-1", r#"{}"#, 3))
        .unwrap();
    store
        .lock()
        .unwrap()
        .push_job(QueueJob::new("vision", "job-2", r#"{}"#, 3))
        .unwrap();

    let jobs = store.lock().unwrap().list_jobs("vision").unwrap();
    assert_eq!(jobs.len(), 2);
    assert_eq!(jobs[0].queue, "vision");
}

// ── Graph Link Tests ──────────────────────────────────────────────────

#[test]
fn test_create_and_get_link() {
    let store = open_store();
    let link = Link::new("player_alice", "played", "match_123");
    let created = store.lock().unwrap().create_link(link).unwrap();
    assert!(!created.id.is_empty());

    let fetched = store.lock().unwrap().get_link(&created.id).unwrap();
    assert!(fetched.is_some());
    assert_eq!(fetched.unwrap().from_ref, "player_alice");
}

#[test]
fn test_get_neighbors_outgoing() {
    let store = open_store();
    store
        .lock()
        .unwrap()
        .create_link(Link::new("player_alice", "played", "match_123"))
        .unwrap();
    store
        .lock()
        .unwrap()
        .create_link(Link::new("player_alice", "played", "match_456"))
        .unwrap();

    let neighbors = store
        .lock()
        .unwrap()
        .get_neighbors("player_alice", LinkDirection::Outgoing, LinkQueryOptions::default())
        .unwrap();
    assert_eq!(neighbors.len(), 2);
    assert!(neighbors.iter().any(|l| l.to_ref == "match_123"));
    assert!(neighbors.iter().any(|l| l.to_ref == "match_456"));
}

#[test]
fn test_get_neighbors_incoming() {
    let store = open_store();
    store
        .lock()
        .unwrap()
        .create_link(Link::new("player_alice", "played", "match_123"))
        .unwrap();
    store
        .lock()
        .unwrap()
        .create_link(Link::new("player_bob", "played", "match_123"))
        .unwrap();

    let neighbors = store
        .lock()
        .unwrap()
        .get_neighbors("match_123", LinkDirection::Incoming, LinkQueryOptions::default())
        .unwrap();
    assert_eq!(neighbors.len(), 2);
}

#[test]
fn test_get_neighbors_with_link_type_filter() {
    let store = open_store();
    store
        .lock()
        .unwrap()
        .create_link(Link::new("player_alice", "played", "match_123"))
        .unwrap();
    store
        .lock()
        .unwrap()
        .create_link(Link::new("player_alice", "authored", "doc_1"))
        .unwrap();

    let options = LinkQueryOptions {
        link_type: Some("played".to_string()),
        ..LinkQueryOptions::default()
    };
    let neighbors = store
        .lock()
        .unwrap()
        .get_neighbors("player_alice", LinkDirection::Outgoing, options)
        .unwrap();
    assert_eq!(neighbors.len(), 1);
    assert_eq!(neighbors[0].link_type, "played");
}

#[test]
fn test_delete_link() {
    let store = open_store();
    let link = store
        .lock()
        .unwrap()
        .create_link(Link::new("alice", "knows", "bob"))
        .unwrap();

    let deleted = store.lock().unwrap().delete_link(&link.id).unwrap();
    assert!(deleted);

    let fetched = store.lock().unwrap().get_link(&link.id).unwrap();
    assert!(fetched.is_none());
}

#[test]
fn test_count_links() {
    let store = open_store();
    store
        .lock()
        .unwrap()
        .create_link(Link::new("a", "knows", "b"))
        .unwrap();
    store
        .lock()
        .unwrap()
        .create_link(Link::new("b", "knows", "c"))
        .unwrap();
    store
        .lock()
        .unwrap()
        .create_link(Link::new("c", "knows", "a"))
        .unwrap();

    let count = store.lock().unwrap().count_links().unwrap();
    assert_eq!(count, 3);
}

// ── TimeSeries Tests ──────────────────────────────────────────────────

#[test]
fn test_timeseries_count() {
    let store = open_store();
    store
        .lock()
        .unwrap()
        .put_object(MemoryObject::new(
            "sales",
            "s1",
            r#"{"amount":100,"date":"2026-01-15T00:00:00Z"}"#,
        ))
        .unwrap();
    store
        .lock()
        .unwrap()
        .put_object(MemoryObject::new(
            "sales",
            "s2",
            r#"{"amount":200,"date":"2026-02-10T00:00:00Z"}"#,
        ))
        .unwrap();

    let options = TimeSeriesOptions {
        function: AggregateFunction::Count,
        bucket: TimeBucket::Month,
        ..TimeSeriesOptions::default()
    };
    let result = store.lock().unwrap().timeseries("sales", &options).unwrap();
    // Should at least not crash and return some buckets
    assert!(!result.buckets.is_empty());
}
