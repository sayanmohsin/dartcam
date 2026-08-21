use std::sync::Mutex;
use std::time::{SystemTime, UNIX_EPOCH};

use thingd::{
    AggregateFunction, AggregateOptions, AggregateStore, EventLog, Link, LinkDirection,
    LinkQueryOptions, LinkStore, ListEventsOptions, MemoryEvent, MemoryObject, ObjectStore,
    PersistentEngine, QueueClaimOptions, QueueJob, QueueNackOptions, QueueStore, SearchOptions,
    Searcher, TimeBucket, TimeSeriesOptions,
};

/// A thread-safe wrapper around thingd's RocksDB-backed persistent engine.
///
/// Exposes all 6 storage traits to Dart via FRB:
/// ObjectStore, EventLog, Searcher, AggregateStore, QueueStore, LinkStore.
pub struct ThingdBridge {
    inner: Mutex<PersistentEngine>,
}

impl ThingdBridge {
    /// Open or create a thingd store at the given file path.
    pub fn open(path: String) -> Result<Self, String> {
        let store = PersistentEngine::open(&path).map_err(|e| e.to_string())?;
        Ok(Self {
            inner: Mutex::new(store),
        })
    }



    // ── Object Store ────────────────────────────────────────────────

    /// Insert or replace an object. Returns the stored body.
    pub fn put_object(
        &self,
        collection: String,
        id: String,
        body: String,
    ) -> Result<String, String> {
        let mut store = self.inner.lock().map_err(|e| e.to_string())?;
        let obj = MemoryObject::new(&collection, &id, &body);
        let result = store.put_object(obj).map_err(|e| e.to_string())?;
        Ok(result.body)
    }

    /// Insert or replace multiple objects in a single transaction.
    pub fn put_objects_batch(
        &self,
        objects: Vec<(String, String, String)>,
    ) -> Result<Vec<String>, String> {
        let mut store = self.inner.lock().map_err(|e| e.to_string())?;
        let items: Vec<MemoryObject> = objects
            .into_iter()
            .map(|(collection, id, body)| MemoryObject::new(collection, id, body))
            .collect();
        let results = store.put_objects_batch(items).map_err(|e| e.to_string())?;
        Ok(results.into_iter().map(|o| o.body).collect())
    }

    /// Read an object by collection and id. Returns None if not found.
    pub fn get_object(
        &self,
        collection: String,
        id: String,
    ) -> Result<Option<String>, String> {
        let store = self.inner.lock().map_err(|e| e.to_string())?;
        let result = store
            .get_object(&collection, &id)
            .map_err(|e| e.to_string())?;
        Ok(result.map(|o| o.body))
    }

    /// Delete an object by collection and id. Returns true if deleted.
    pub fn delete_object(
        &self,
        collection: String,
        id: String,
    ) -> Result<bool, String> {
        let mut store = self.inner.lock().map_err(|e| e.to_string())?;
        store
            .delete_object(&collection, &id)
            .map_err(|e| e.to_string())
    }

    /// Delete multiple objects in a single transaction. Returns count deleted.
    pub fn delete_objects_batch(
        &self,
        keys: Vec<(String, String)>,
    ) -> Result<u64, String> {
        let mut store = self.inner.lock().map_err(|e| e.to_string())?;
        store
            .delete_objects_batch(&keys)
            .map_err(|e| e.to_string())
    }

    /// List all object IDs in a collection. Returns (id, body) pairs.
    /// `limit` max results (0 for all). `offset` for pagination.
    pub fn list_objects(
        &self,
        collection: String,
        limit: u64,
        offset: u64,
    ) -> Result<Vec<(String, String)>, String> {
        let store = self.inner.lock().map_err(|e| e.to_string())?;
        let collections = Some(vec![collection]);
        let options = thingd::ListObjectsOptions {
            limit: if limit == 0 { None } else { Some(limit) },
            offset: if offset == 0 { None } else { Some(offset) },
            ..thingd::ListObjectsOptions::default()
        };
        let objects = store
            .list_objects(collections.as_deref(), &options)
            .map_err(|e| e.to_string())?;
        Ok(objects.into_iter().map(|o| (o.key.id, o.body)).collect())
    }

    // ── Event Log ───────────────────────────────────────────────────

    /// Append an event to a stream. Returns the stored event body.
    pub fn append_event(
        &self,
        stream: String,
        event_type: String,
        body: String,
    ) -> Result<String, String> {
        let mut store = self.inner.lock().map_err(|e| e.to_string())?;
        let event = MemoryEvent::new(&stream, &event_type, &body);
        let result = store.append_event(event).map_err(|e| e.to_string())?;
        Ok(result.body)
    }

    /// Append multiple events to a stream in a single transaction.
    pub fn append_events_batch(
        &self,
        stream: String,
        events: Vec<(String, String)>,
    ) -> Result<Vec<String>, String> {
        let mut store = self.inner.lock().map_err(|e| e.to_string())?;
        let items: Vec<MemoryEvent> = events
            .into_iter()
            .map(|(event_type, body)| MemoryEvent::new(&stream, &event_type, &body))
            .collect();
        let results = store
            .append_events_batch(items)
            .map_err(|e| e.to_string())?;
        Ok(results.into_iter().map(|e| e.body).collect())
    }

    /// List all events in a stream, in ascending sequence order.
    pub fn list_events(&self, stream: String) -> Result<Vec<String>, String> {
        let store = self.inner.lock().map_err(|e| e.to_string())?;
        let events = store
            .list_events(Some(&stream), ListEventsOptions::default())
            .map_err(|e| e.to_string())?;
        Ok(events.into_iter().map(|e| e.body).collect())
    }

    /// List events from a given sequence number. Returns (body, sequence) pairs.
    pub fn list_events_from(
        &self,
        stream: String,
        from_sequence: u64,
        limit: u64,
    ) -> Result<Vec<(String, u64)>, String> {
        let store = self.inner.lock().map_err(|e| e.to_string())?;
        let options = ListEventsOptions {
            from_sequence: Some(from_sequence),
            limit: if limit == 0 { None } else { Some(limit) },
        };
        let events = store
            .list_events(Some(&stream), options)
            .map_err(|e| e.to_string())?;
        Ok(events.into_iter().map(|e| (e.body, e.sequence)).collect())
    }

    /// Delete the most recent event from a stream.
    pub fn delete_last_event(&self, stream: String) -> Result<Option<String>, String> {
        let mut store = self.inner.lock().map_err(|e| e.to_string())?;
        let result = store
            .delete_last_event(&stream)
            .map_err(|e| e.to_string())?;
        Ok(result.map(|e| e.body))
    }

    /// Delete all events in a stream. Returns the count of deleted events.
    pub fn delete_stream(&self, stream: String) -> Result<u64, String> {
        let mut store = self.inner.lock().map_err(|e| e.to_string())?;
        store.delete_stream(&stream).map_err(|e| e.to_string())
    }

    // ── Search (Searcher trait) ─────────────────────────────────────

    /// Full-text search across objects and events.
    ///
    /// Returns JSON array of search hits with id, collection, text, score, kind.
    pub fn search(
        &self,
        query: String,
        collection: String,
        limit: u64,
    ) -> Result<Vec<String>, String> {
        let store = self.inner.lock().map_err(|e| e.to_string())?;
        let collections = if collection.is_empty() {
            None
        } else {
            Some(vec![collection])
        };
        let limit_usize = if limit == 0 {
            None
        } else {
            Some(usize::try_from(limit).unwrap_or(usize::MAX))
        };
        let options = SearchOptions {
            collections,
            limit: limit_usize,
            ..SearchOptions::default()
        };
        let hits = store.search(&query, options).map_err(|e| e.to_string())?;
        Ok(hits
            .iter()
            .map(|h| {
                serde_json::json!({
                    "id": h.id,
                    "collection": h.collection,
                    "text": h.text,
                    "score": h.score,
                    "kind": h.kind,
                    "body": h.body,
                })
                .to_string()
            })
            .collect())
    }

    // ── Aggregation (AggregateStore trait) ──────────────────────────

    /// Run an aggregation over a collection.
    ///
    /// `params` is a JSON string:
    ///   { "function": "count|sum|avg|min|max",
    ///     "field": "...", "groupBy": "..." }
    /// Returns JSON result with total and groups.
    pub fn aggregate(&self, collection: String, params: String) -> Result<String, String> {
        let store = self.inner.lock().map_err(|e| e.to_string())?;
        let p: serde_json::Value =
            serde_json::from_str(&params).map_err(|e| format!("invalid params: {e}"))?;

        let function = parse_agg_function(p["function"].as_str().unwrap_or("count"));
        let field = p["field"].as_str().map(|s| s.to_string());
        let group_by = p["groupBy"].as_str().map(|s| s.to_string());

        let options = AggregateOptions {
            function,
            field,
            group_by,
            ..AggregateOptions::default()
        };

        let result = store
            .aggregate(&collection, &options)
            .map_err(|e| e.to_string())?;
        serde_json::to_string(&result).map_err(|e| e.to_string())
    }

    /// Run a time-bucketed aggregation.
    ///
    /// `params` is a JSON string:
    ///   { "function": "...", "field": "...",
    ///     "bucket": "hour|day|week|month",
    ///     "from": "ISO8601", "to": "ISO8601" }
    pub fn timeseries(&self, collection: String, params: String) -> Result<String, String> {
        let store = self.inner.lock().map_err(|e| e.to_string())?;
        let p: serde_json::Value =
            serde_json::from_str(&params).map_err(|e| format!("invalid params: {e}"))?;

        let function = parse_agg_function(p["function"].as_str().unwrap_or("count"));
        let field = p["field"].as_str().map(|s| s.to_string());
        let bucket = parse_time_bucket(p["bucket"].as_str().unwrap_or("day"));
        let from = p["from"].as_str().map(|s| s.to_string());
        let to = p["to"].as_str().map(|s| s.to_string());

        let options = TimeSeriesOptions {
            function,
            field,
            bucket,
            from,
            to,
            ..TimeSeriesOptions::default()
        };

        let result = store
            .timeseries(&collection, &options)
            .map_err(|e| e.to_string())?;
        serde_json::to_string(&result).map_err(|e| e.to_string())
    }

    // ── Queue Store (QueueStore trait) ───────────────────────────────

    /// Push a job onto a queue. Returns the job id.
    ///
    /// `body` is the job payload as a JSON string.
    /// `max_attempts` is the max retry count before dead-letter.
    /// If `job_id` is empty, one is auto-generated.
    pub fn push_job(
        &self,
        queue: String,
        job_id: String,
        body: String,
        max_attempts: u32,
    ) -> Result<String, String> {
        let mut store = self.inner.lock().map_err(|e| e.to_string())?;
        let id = if job_id.is_empty() {
            generate_id()
        } else {
            job_id
        };
        let job = QueueJob::new(&queue, &id, &body, max_attempts);
        let result = store.push_job(job).map_err(|e| e.to_string())?;
        Ok(result.id)
    }

    /// Claim the next ready job from a queue. Returns JSON or empty string.
    ///
    /// Returns JSON with id, queue, body, status, attempts.
    /// Returns empty string if no job available.
    pub fn claim_job(&self, queue: String, lease_ms: u64) -> Result<String, String> {
        let mut store = self.inner.lock().map_err(|e| e.to_string())?;
        let options = QueueClaimOptions { lease_ms };
        let result = store
            .claim_job_with_options(&queue, options)
            .map_err(|e| e.to_string())?;
        Ok(result.map_or(String::new(), |j| job_to_json(&j)))
    }

    /// Acknowledge a leased job as completed. Returns true if acked.
    pub fn ack_job(&self, queue: String, job_id: String) -> Result<bool, String> {
        let mut store = self.inner.lock().map_err(|e| e.to_string())?;
        let result = store.ack_job(&queue, &job_id).map_err(|e| e.to_string())?;
        Ok(result.is_some())
    }

    /// Reject a leased job for retry or dead-letter routing.
    pub fn nack_job(
        &self,
        queue: String,
        job_id: String,
        delay_ms: u64,
        error: String,
    ) -> Result<bool, String> {
        let mut store = self.inner.lock().map_err(|e| e.to_string())?;
        let options = QueueNackOptions {
            delay_ms,
            error,
        };
        let result = store
            .nack_job_with_options(&queue, &job_id, options)
            .map_err(|e| e.to_string())?;
        Ok(result.is_some())
    }

    /// List all jobs in a queue. Returns JSON array.
    pub fn list_jobs(&self, queue: String) -> Result<Vec<String>, String> {
        let store = self.inner.lock().map_err(|e| e.to_string())?;
        let jobs = store.list_jobs(&queue).map_err(|e| e.to_string())?;
        Ok(jobs.iter().map(job_to_json).collect())
    }

    /// List dead-letter jobs in a queue. Returns JSON array.
    pub fn list_dead_jobs(&self, queue: String) -> Result<Vec<String>, String> {
        let store = self.inner.lock().map_err(|e| e.to_string())?;
        let jobs = store.list_dead_jobs(&queue).map_err(|e| e.to_string())?;
        Ok(jobs.iter().map(job_to_json).collect())
    }

    // ── Graph Links (LinkStore trait) ────────────────────────────────

    /// Create a directed link between two references. Returns the link id.
    pub fn create_link(
        &self,
        from_ref: String,
        link_type: String,
        to_ref: String,
    ) -> Result<String, String> {
        let mut store = self.inner.lock().map_err(|e| e.to_string())?;
        let link = Link::new(&from_ref, &link_type, &to_ref);
        let result = store.create_link(link).map_err(|e| e.to_string())?;
        Ok(result.id)
    }

    /// Delete a link by id. Returns true if deleted.
    pub fn delete_link(&self, id: String) -> Result<bool, String> {
        let mut store = self.inner.lock().map_err(|e| e.to_string())?;
        store.delete_link(&id).map_err(|e| e.to_string())
    }

    /// Get neighbors of a reference. Returns JSON array of links.
    ///
    /// `direction`: "Outgoing", "Incoming", or "Both" (default).
    /// `link_type`: optional filter.
    pub fn get_neighbors(
        &self,
        reference: String,
        direction: String,
        link_type: Option<String>,
    ) -> Result<Vec<String>, String> {
        let store = self.inner.lock().map_err(|e| e.to_string())?;
        let dir = match direction.as_str() {
            "Outgoing" => LinkDirection::Outgoing,
            "Incoming" => LinkDirection::Incoming,
            _ => LinkDirection::Both,
        };
        let options = LinkQueryOptions {
            link_type,
            ..LinkQueryOptions::default()
        };
        let links = store
            .get_neighbors(&reference, dir, options)
            .map_err(|e| e.to_string())?;
        Ok(links
            .iter()
            .map(|l| {
                serde_json::json!({
                    "id": l.id,
                    "fromRef": l.from_ref,
                    "linkType": l.link_type,
                    "toRef": l.to_ref,
                    "createdAt": l.created_at,
                })
                .to_string()
            })
            .collect())
    }

    /// Count total links.
    pub fn count_links(&self) -> Result<u64, String> {
        let store = self.inner.lock().map_err(|e| e.to_string())?;
        store.count_links().map_err(|e| e.to_string())
    }

    // ── Lifecycle ───────────────────────────────────────────────────

    /// Flush the SQLite WAL into the main database file.
    pub fn wal_checkpoint(&self) -> Result<(i32, i32), String> {
        let store = self.inner.lock().map_err(|e| e.to_string())?;
        store.wal_checkpoint().map_err(|e| e.to_string())
    }

    /// Optimize the FTS5 search index to merge segments.
    pub fn optimize_search_index(&self) -> Result<(), String> {
        let store = self.inner.lock().map_err(|e| e.to_string())?;
        store.optimize_search_index().map_err(|e| e.to_string())
    }
}

// ── Helpers ─────────────────────────────────────────────────────────

fn parse_agg_function(s: &str) -> AggregateFunction {
    match s {
        "sum" => AggregateFunction::Sum,
        "avg" => AggregateFunction::Avg,
        "min" => AggregateFunction::Min,
        "max" => AggregateFunction::Max,
        _ => AggregateFunction::Count,
    }
}

fn parse_time_bucket(s: &str) -> TimeBucket {
    match s {
        "hour" => TimeBucket::Hour,
        "week" => TimeBucket::Week,
        "month" => TimeBucket::Month,
        _ => TimeBucket::Day,
    }
}

fn generate_id() -> String {
    let ms = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis();
    format!("job_{ms}")
}

fn job_to_json(j: &QueueJob) -> String {
    serde_json::json!({
        "id": j.id,
        "queue": j.queue,
        "body": j.body,
        "status": format!("{:?}", j.status),
        "attempts": j.attempts,
        "maxAttempts": j.max_attempts,
        "createdAt": j.created_at,
        "lastError": j.last_error,
    })
    .to_string()
}
