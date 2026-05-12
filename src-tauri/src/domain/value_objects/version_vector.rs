use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct VersionVector {
    pub device_id: Uuid,
    pub version: u64,
    pub vector: HashMap<Uuid, u64>,
}

impl VersionVector {
    pub fn new(device_id: Uuid) -> Self {
        let mut vector = HashMap::new();
        vector.insert(device_id, 1);
        Self {
            device_id,
            version: 1,
            vector,
        }
    }

    pub fn increment(&mut self) {
        self.version += 1;
        self.vector.insert(self.device_id, self.version);
    }

    pub fn merge(&mut self, other: &VersionVector) {
        for (device_id, version) in &other.vector {
            let current = self.vector.get(device_id).copied().unwrap_or(0);
            if *version > current {
                self.vector.insert(*device_id, *version);
            }
        }
    }

    pub fn is_concurrent_with(&self, other: &VersionVector) -> bool {
        let self_dominates = self.dominates(other);
        let other_dominates = other.dominates(self);
        !self_dominates && !other_dominates
    }

    fn dominates(&self, other: &VersionVector) -> bool {
        let mut has_greater = false;
        for (device_id, other_version) in &other.vector {
            let self_version = self.vector.get(device_id).copied().unwrap_or(0);
            if self_version < *other_version {
                return false;
            }
            if self_version > *other_version {
                has_greater = true;
            }
        }
        has_greater
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_version_vector_creation() {
        let device_id = Uuid::new_v4();
        let vv = VersionVector::new(device_id);

        assert_eq!(vv.device_id, device_id);
        assert_eq!(vv.version, 1);
        assert_eq!(vv.vector.len(), 1);
        assert_eq!(vv.vector.get(&device_id), Some(&1));
    }

    #[test]
    fn test_increment_operation() {
        let device_id = Uuid::new_v4();
        let mut vv = VersionVector::new(device_id);

        vv.increment();
        assert_eq!(vv.version, 2);
        assert_eq!(vv.vector.get(&device_id), Some(&2));

        vv.increment();
        assert_eq!(vv.version, 3);
        assert_eq!(vv.vector.get(&device_id), Some(&3));
    }

    #[test]
    fn test_merge_operation() {
        let device1 = Uuid::new_v4();
        let device2 = Uuid::new_v4();

        let mut vv1 = VersionVector::new(device1);
        vv1.increment(); // device1: 2

        let mut vv2 = VersionVector::new(device2);
        vv2.increment(); // device2: 2
        vv2.increment(); // device2: 3

        vv1.merge(&vv2);

        assert_eq!(vv1.vector.get(&device1), Some(&2));
        assert_eq!(vv1.vector.get(&device2), Some(&3));
    }

    #[test]
    fn test_merge_with_higher_version() {
        let device1 = Uuid::new_v4();
        let device2 = Uuid::new_v4();

        let mut vv1 = VersionVector::new(device1);
        vv1.increment(); // device1: 2

        let mut vv2 = VersionVector::new(device2);
        vv2.vector.insert(device1, 5); // device2 knows device1 is at 5

        vv1.merge(&vv2);

        // vv1 should now have device1: 5 (from vv2, higher than local 2)
        assert_eq!(vv1.vector.get(&device1), Some(&5));
        assert_eq!(vv1.vector.get(&device2), Some(&1));
    }

    #[test]
    fn test_merge_with_lower_version() {
        let device1 = Uuid::new_v4();
        let device2 = Uuid::new_v4();

        let mut vv1 = VersionVector::new(device1);
        vv1.increment(); // device1: 2
        vv1.increment(); // device1: 3
        vv1.increment(); // device1: 4

        let mut vv2 = VersionVector::new(device2);
        vv2.vector.insert(device1, 2); // device2 knows device1 is at 2

        vv1.merge(&vv2);

        // vv1 should keep device1: 4 (local is higher than vv2's 2)
        assert_eq!(vv1.vector.get(&device1), Some(&4));
        assert_eq!(vv1.vector.get(&device2), Some(&1));
    }

    #[test]
    fn test_concurrent_detection_true() {
        let device1 = Uuid::new_v4();
        let device2 = Uuid::new_v4();

        let mut vv1 = VersionVector::new(device1);
        vv1.increment(); // device1: 2

        let mut vv2 = VersionVector::new(device2);
        vv2.increment(); // device2: 2

        // Both have updates the other doesn't know about - concurrent
        assert!(vv1.is_concurrent_with(&vv2));
        assert!(vv2.is_concurrent_with(&vv1));
    }

    #[test]
    fn test_concurrent_detection_false_when_one_dominates() {
        let device1 = Uuid::new_v4();
        let device2 = Uuid::new_v4();

        let mut vv1 = VersionVector::new(device1);
        vv1.increment(); // device1: 2

        let mut vv2 = VersionVector::new(device2);
        vv2.vector.insert(device1, 2); // vv2 knows about device1's updates
        vv2.increment(); // device2: 2

        // vv2 dominates vv1 (knows everything vv1 knows, plus more)
        assert!(!vv1.is_concurrent_with(&vv2));
        assert!(!vv2.is_concurrent_with(&vv1));
    }

    #[test]
    fn test_dominance_detection() {
        let device1 = Uuid::new_v4();
        let device2 = Uuid::new_v4();

        let mut vv1 = VersionVector::new(device1);
        vv1.increment(); // device1: 2

        let mut vv2 = VersionVector::new(device2);
        vv2.vector.insert(device1, 2); // vv2 knows about device1
        vv2.increment(); // device2: 2

        // vv2 dominates vv1
        assert!(vv2.dominates(&vv1));
        assert!(!vv1.dominates(&vv2));
    }

    #[test]
    fn test_dominance_requires_greater_version() {
        let device1 = Uuid::new_v4();

        let vv1 = VersionVector::new(device1);
        let vv2 = VersionVector::new(device1);

        // Same versions - neither dominates
        assert!(!vv1.dominates(&vv2));
        assert!(!vv2.dominates(&vv1));
    }

    #[test]
    fn test_serialization_deserialization() {
        let device_id = Uuid::new_v4();
        let mut vv = VersionVector::new(device_id);
        vv.increment();

        let serialized = serde_json::to_string(&vv).unwrap();
        let deserialized: VersionVector = serde_json::from_str(&serialized).unwrap();

        assert_eq!(vv, deserialized);
        assert_eq!(deserialized.device_id, device_id);
        assert_eq!(deserialized.version, 2);
        assert_eq!(deserialized.vector.get(&device_id), Some(&2));
    }

    #[test]
    fn test_complex_merge_scenario() {
        let device1 = Uuid::new_v4();
        let device2 = Uuid::new_v4();
        let device3 = Uuid::new_v4();

        // Device 1 makes updates
        let mut vv1 = VersionVector::new(device1);
        vv1.increment(); // device1: 2
        vv1.increment(); // device1: 3

        // Device 2 makes updates
        let mut vv2 = VersionVector::new(device2);
        vv2.increment(); // device2: 2

        // Device 3 makes updates
        let mut vv3 = VersionVector::new(device3);
        vv3.increment(); // device3: 2
        vv3.increment(); // device3: 3
        vv3.increment(); // device3: 4

        // Merge all into vv1
        vv1.merge(&vv2);
        vv1.merge(&vv3);

        assert_eq!(vv1.vector.get(&device1), Some(&3));
        assert_eq!(vv1.vector.get(&device2), Some(&2));
        assert_eq!(vv1.vector.get(&device3), Some(&4));
    }

    #[test]
    fn test_concurrent_with_multiple_devices() {
        let device1 = Uuid::new_v4();
        let device2 = Uuid::new_v4();
        let device3 = Uuid::new_v4();

        let mut vv1 = VersionVector::new(device1);
        vv1.vector.insert(device2, 5);
        vv1.vector.insert(device3, 3);

        let mut vv2 = VersionVector::new(device2);
        vv2.vector.insert(device1, 1);
        vv2.vector.insert(device3, 7);

        // vv1 has higher device2 (5 vs 1) but lower device3 (3 vs 7)
        // This is concurrent
        assert!(vv1.is_concurrent_with(&vv2));
    }
}
