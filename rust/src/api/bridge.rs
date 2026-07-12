use std::sync::Mutex;

use thingd::{
    EventLog, ListEventsOptions, MemoryEvent, MemoryObject, ObjectStore, SqliteThingStore,
};

/// A thread-safe wrapper around thingd's SQLite-backed store.
///
/// Exposes object storage and event log operations to Dart via FRB.
pub struct ThingdBridge {
    inner: Mutex<SqliteThingStore>,
}

impl ThingdBridge {
    /// Open or create a thingd store at the given file path.
    pub fn open(path: String) -> Result<Self, String> {
        let store = SqliteThingStore::open(&path).map_err(|e| e.to_string())?;
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
    ///
    /// Only returns events with sequence > `from_sequence`, up to `limit`.
    /// Pass `from_sequence: 0` to get all events. Pass `limit: 0` for no limit.
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
    /// Returns the deleted event body, or None if the stream was empty.
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

    // ── Lifecycle ───────────────────────────────────────────────────

    /// Flush the SQLite WAL into the main database file.
    ///
    /// Call this before the app goes to background to prevent data loss.
    /// Returns `(frames_before, frames_after)` where frames_after should be 0.
    pub fn wal_checkpoint(&self) -> Result<(i32, i32), String> {
        let store = self.inner.lock().map_err(|e| e.to_string())?;
        store.wal_checkpoint().map_err(|e| e.to_string())
    }

    /// Optimize the FTS5 search index to merge segments and reclaim space.
    ///
    /// Run periodically (e.g. every 50 matches) to prevent search
    /// performance degradation from index fragmentation.
    pub fn optimize_search_index(&self) -> Result<(), String> {
        let store = self.inner.lock().map_err(|e| e.to_string())?;
        store.optimize_search_index().map_err(|e| e.to_string())
    }
}
