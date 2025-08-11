package ingest

import (
	"bytes"
	"encoding/csv"
	"errors"
	"io"
	"strings"
)

type CSVParser struct{}

func (p CSVParser) Detect(b []byte) bool {
	return !bytes.Contains(bytes.ToUpper(b), []byte("<OFX>"))
}

func (p CSVParser) Parse(b []byte) ([]Row, error) {
	r := csv.NewReader(bytes.NewReader(b));
	r.FieldsPerRecord = -1
	header, err := r.Read();
	if err != nil {
		return nil, err
	}

	m := indexMap(header) // map common header aliases
	var out []Row
	for ln := 2; ; ln++ {
		rec, err := r.Read(); if errors.Is(err, io.EOF) { break }
		if err != nil { return nil, err }
		date, ok := parseDate(pick(rec, m["date"])); if !ok { continue }
		amt := parseAmount(rec, m)
		desc := strings.TrimSpace(pick(rec, m["description"]))
		out = append(out, Row{
			Date: date,
			Description: desc,
			Normalized: normalizeDesc(desc),
			Amount: amt,
			Currency: pickOr("USD", rec, m["currency"]),
			RawLine: strings.Join(rec, ","),
		})
	}
	return out, nil
}

func parseAmount(rec []string, m interface{}) interface{} {
	
}

func parseDate(i interface{}) (interface{}, interface{}) {
	
}

func indexMap(header []string) interface{} {
	
}