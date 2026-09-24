# PROMETHEUS V2 — STORAGE ADAPTER CONTRACT v1

## Purpose

Canonical interface between Prometheus V2 orchestration and object
storage.

Current implementation:

    SEAWEEDFS_S3

The orchestration layer MUST NOT depend directly on provider-specific
storage implementation details.

## Operations

### PUT

Input:

- bucket
- object_key
- local_file
- content_type (optional)

Expected result:

- success
- bucket
- object_key
- size_bytes
- sha256

### HEAD

Input:

- bucket
- object_key

Expected result:

- exists
- size_bytes
- content_type
- last_modified

### GET

Input:

- bucket
- object_key
- destination_file

Expected result:

- success
- local_file
- size_bytes
- sha256

### DELETE

Input:

- bucket
- object_key

Expected result:

- success

## Rules

1. Production and test buckets are isolated.
2. object_key is the canonical physical identity of an artifact.
3. A VALIDATED artifact requires physical presence.
4. SHA-256 must be calculated for validated production artifacts.
5. Storage errors must be explicit.
6. The adapter must never silently recreate or repair registry rows.
7. Registry state remains PostgreSQL responsibility.
8. The adapter must not contain production-stage business logic.
