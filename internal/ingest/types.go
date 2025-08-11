package ingest

import "time"

type Row struct {
	Date        time.Time
	Description string
	Normalized  string
	Amount      float64 // negative = outflow
	Currency    string
	RawLine     string  // for audit
}

type Parser interface {
	Detect([]byte) bool
	Parse([]byte) ([]Row, error)
}