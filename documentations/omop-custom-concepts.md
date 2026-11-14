# OMOP custom concepts

Tamanu data that has no standard OMOP concept, such as a deployment's ethnicity list, is coded as
OMOP custom concepts. OMOP reserves concept IDs from 2,000,000,000 for local use, and the largest
ID an OMOP `concept_id` (a 4-byte integer) can hold is 2,147,483,647.

## Rules

- Each deployment codes its custom concepts from its own block, listed below. A deployment takes the
  next free block in this register before issuing its first custom concept.
- A concept ID is fixed once issued. It is never renumbered and never reissued to another value,
  including after the value is retired in Tamanu.
- Within its block, a deployment issues IDs in sequence across all its local vocabularies. The
  `vocabulary_id` tells the vocabularies apart.
- Blocks are 1,000,000 IDs wide. The first block, 2,000,000,000 to 2,000,999,999, is held for
  concepts every deployment shares.

## Register

| Block | IDs | Holder | Vocabularies |
|---|---|---|---|
| 0 | 2,000,000,000 – 2,000,999,999 | Shared by every deployment | None yet |
| 1 | 2,001,000,000 – 2,001,999,999 | `tamanu-dbt-fiji` | Ethnicity (`map__omop_ethnicity`) |
