package types

// PageRequest represents cursor-based pagination input.
type PageRequest struct {
	PageSize  int32
	PageToken string
}

// PageResponse contains pagination metadata.
type PageResponse struct {
	NextPageToken string
	TotalCount    int32
}

// PaginatedResult wraps a slice of results with pagination metadata.
type PaginatedResult[T any] struct {
	Items         []T
	NextPageToken string
	TotalCount    int32
}
