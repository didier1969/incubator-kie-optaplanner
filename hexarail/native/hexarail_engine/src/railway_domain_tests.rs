// Copyright (c) Didier Stadelmann. All rights reserved.

use crate::domain::GeoPoint;
use crate::railway_domain::{GtfsStop, SystemHealth};

#[test]
fn test_system_health_struct() {
    let health = SystemHealth {
        total_delay_seconds: 3600,
        active_conflicts: 5,
        broken_connections: 2,
        active_perturbations: 1,
    };
    assert_eq!(health.total_delay_seconds, 3600);
}

#[test]
fn test_gtfs_stop_struct() {
    let stop = GtfsStop {
        id: 1,
        original_stop_id: "8500010".to_string(),
        stop_name: "Basel SBB".to_string(),
        abbreviation: Some("BS".to_string()),
        location_type: Some(1),
        parent_station: None,
        platform_code: Some("4".to_string()),
        location: GeoPoint {
            coordinates: (7.589, 47.547),
            srid: Some(4326),
        },
    };
    assert_eq!(stop.stop_name, "Basel SBB");
}
