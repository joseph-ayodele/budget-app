package event_store

import (
	"database/sql"
	"time"
)

type Event struct {
	StreamID   string
	StreamType string
	Version    int
	EventType  string
	Payload    []byte
	OccurredAt time.Time
}

type Store struct {
	db *sql.DB
}

func NewStore(db *sql.DB) *Store {
	return &Store{db: db}
}

func (s *Store) Append(ctx context.Context, tx *sql.Tx, streamID, streamType string, events []Event) error {
	// fetch current max version
	var ver int
	err := tx.QueryRowContext(ctx, `SELECT COALESCE(MAX(version),0) FROM event_store WHERE stream_id=$1`, streamID).Scan(&ver)
	if err != nil { return err }
	for i := range events {
		events[i].Version = ver + 1 + i
		_, err = tx.ExecContext(ctx, `
          INSERT INTO event_store(stream_id,stream_type,version,event_type,payload)
          VALUES($1,$2,$3,$4,$5)`,
			streamID, streamType, events[i].Version, events[i].EventType, events[i].Payload)
		if err != nil { return err }
	}
	return nil
}