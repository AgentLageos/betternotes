//! Least-recently-used cache with a byte budget, for rendered tiles.

use std::collections::HashMap;
use std::hash::Hash;

struct Entry<V> {
    value: V,
    bytes: usize,
    last_used: u64,
}

/// LRU cache limited by the total size of its values (given on insert).
///
/// Eviction scans all entries for the oldest one; fine for the few hundred tiles a budget of some
/// tens of MB holds.
pub struct LruCache<K, V> {
    entries: HashMap<K, Entry<V>>,
    budget: usize,
    bytes: usize,
    clock: u64,
}

impl<K: Eq + Hash + Clone, V> LruCache<K, V> {
    pub fn new(budget_bytes: usize) -> Self {
        Self { entries: HashMap::new(), budget: budget_bytes, bytes: 0, clock: 0 }
    }

    pub fn len(&self) -> usize {
        self.entries.len()
    }

    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }

    /// Total size of the cached values.
    pub fn bytes(&self) -> usize {
        self.bytes
    }

    /// The value for `key`, marking it as recently used.
    pub fn get(&mut self, key: &K) -> Option<&V> {
        self.clock += 1;
        let clock = self.clock;
        self.entries.get_mut(key).map(|e| {
            e.last_used = clock;
            &e.value
        })
    }

    /// Inserts or replaces `key`, then evicts the least recently used entries until the budget
    /// holds. A value larger than the whole budget is not stored.
    pub fn insert(&mut self, key: K, value: V, bytes: usize) {
        self.remove(&key);
        if bytes > self.budget {
            return;
        }
        self.clock += 1;
        self.bytes += bytes;
        self.entries.insert(key, Entry { value, bytes, last_used: self.clock });
        while self.bytes > self.budget {
            let oldest = self.entries.iter().min_by_key(|(_, e)| e.last_used).map(|(k, _)| k.clone());
            match oldest {
                Some(k) => self.remove(&k),
                None => break,
            };
        }
    }

    pub fn remove(&mut self, key: &K) -> Option<V> {
        self.entries.remove(key).map(|e| {
            self.bytes -= e.bytes;
            e.value
        })
    }

    /// Removes all entries for which `drop` returns true.
    pub fn remove_where(&mut self, mut drop: impl FnMut(&K) -> bool) {
        let bytes = &mut self.bytes;
        self.entries.retain(|k, e| {
            let remove = drop(k);
            if remove {
                *bytes -= e.bytes;
            }
            !remove
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn evicts_least_recently_used() {
        let mut cache = LruCache::new(30);
        cache.insert("a", 1, 10);
        cache.insert("b", 2, 10);
        cache.insert("c", 3, 10);
        cache.get(&"a");
        cache.insert("d", 4, 10); // evicts b
        assert!(cache.get(&"b").is_none());
        assert_eq!(cache.get(&"a"), Some(&1));
        assert_eq!(cache.bytes(), 30);
    }

    #[test]
    fn replacing_updates_the_size() {
        let mut cache = LruCache::new(100);
        cache.insert("a", 1, 10);
        cache.insert("a", 2, 50);
        assert_eq!(cache.bytes(), 50);
        assert_eq!(cache.len(), 1);
        cache.insert("big", 3, 101);
        assert!(cache.get(&"big").is_none());
        cache.remove_where(|k| *k == "a");
        assert!(cache.is_empty());
        assert_eq!(cache.bytes(), 0);
    }
}
