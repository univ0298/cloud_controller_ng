# 1. Duplicate models that we want to snapshot into revisions

Date: 2019-09-25

## Context

After implementing `RevisionSidecarProcessTypeModel`, we started to question why we've got so many `Revision`-prefixed models. 

To back up all the data we needed into revision, early on we had to make a lot of data modeling decisions that we are now continuing for consistency reasons. 

## Decision

When backing configuration data up into a revision, create extra models to store that data, do not reuse models that don't already serve as a historical record.

Why? what bits of the revision model necessitated this?

## Consequences

*******