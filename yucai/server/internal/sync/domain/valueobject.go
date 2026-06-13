package domain

// SyncOperation represents the type of change performed on an entity.
type SyncOperation int

const (
	SyncOperationCreate SyncOperation = iota + 1
	SyncOperationUpdate
	SyncOperationDelete
)

func (o SyncOperation) String() string {
	switch o {
	case SyncOperationCreate:
		return "create"
	case SyncOperationUpdate:
		return "update"
	case SyncOperationDelete:
		return "delete"
	default:
		return "unknown"
	}
}

func ParseSyncOperation(s string) SyncOperation {
	switch s {
	case "create":
		return SyncOperationCreate
	case "update":
		return SyncOperationUpdate
	case "delete":
		return SyncOperationDelete
	default:
		return 0
	}
}

// ConflictResolution represents how a sync conflict was resolved.
type ConflictResolution int

const (
	ConflictResolutionPending ConflictResolution = iota
	ConflictResolutionServerWins
	ConflictResolutionClientWins
	ConflictResolutionMerged
)

func (r ConflictResolution) String() string {
	switch r {
	case ConflictResolutionServerWins:
		return "server"
	case ConflictResolutionClientWins:
		return "client"
	case ConflictResolutionMerged:
		return "merged"
	default:
		return "pending"
	}
}

func ParseConflictResolution(s string) ConflictResolution {
	switch s {
	case "server":
		return ConflictResolutionServerWins
	case "client":
		return ConflictResolutionClientWins
	case "merged":
		return ConflictResolutionMerged
	default:
		return ConflictResolutionPending
	}
}

// PageRequest is a shared pagination type.
type PageRequest = struct {
	PageSize  int32
	PageToken string
}

// PaginatedResult is a generic paginated response.
type PaginatedResult[T any] = struct {
	Items         []T
	NextPageToken string
	TotalCount    int32
}
