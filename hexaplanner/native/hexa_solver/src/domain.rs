use rustler::NifStruct;

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaPlanner.Domain.Resource"]
pub struct Resource {
    pub id: i64,
    pub name: String,
    pub capacity: i64,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaPlanner.Domain.Job"]
pub struct Job {
    pub id: i64,
    pub duration: i64,
    pub required_resources: Vec<i64>,
    pub start_time: Option<i64>,
}

#[derive(Debug, Clone, NifStruct)]
#[module = "HexaPlanner.Domain.Problem"]
pub struct Problem {
    pub id: String,
    pub resources: Vec<Resource>,
    pub jobs: Vec<Job>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_domain_clone() {
        let j1 = Job { id: 1, duration: 10, required_resources: vec![], start_time: None };
        let j2 = j1.clone();
        assert_eq!(j1.id, j2.id);
    }

    #[test]
    fn test_problem_instantiation() {
        let r1 = Resource { id: 1, name: "Machine".to_string(), capacity: 1 };
        let j1 = Job { id: 100, duration: 60, required_resources: vec![1], start_time: None };
        let problem = Problem { id: "sim_1".to_string(), resources: vec![r1], jobs: vec![j1] };
        
        assert_eq!(problem.jobs.len(), 1);
    }
}