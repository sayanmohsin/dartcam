use std::sync::Mutex;

use thingd::{EventLog, ListEventsOptions, MemoryEvent, ObjectStore, SqliteThingStore};

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

    /// Insert or replace an object. Returns the stored body.
    pub fn put_object(
        &self,
        collection: String,
        id: String,
        body: String,
    ) -> Result<String, String> {
        let mut store = self.inner.lock().map_err(|e| e.to_string())?;
        let obj = thingd::MemoryObject::new(&collection, &id, &body);
        let result = store.put_object(obj).map_err(|e| e.to_string())?;
        Ok(result.body)
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

    /// List all events in a stream, in ascending sequence order.
    pub fn list_events(&self, stream: String) -> Result<Vec<String>, String> {
        let store = self.inner.lock().map_err(|e| e.to_string())?;
        let events = store
            .list_events(Some(&stream), ListEventsOptions::default())
            .map_err(|e| e.to_string())?;
        Ok(events.into_iter().map(|e| e.body).collect())
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
}
