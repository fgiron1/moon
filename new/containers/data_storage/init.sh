#!/bin/bash

# Custom Neo4j initialization script

# Set up necessary directory permissions
chmod -R 777 /import
chmod -R 777 /logs

# Create initial constraints and indexes
cypher-shell -u neo4j -p osintpassword "CREATE CONSTRAINT entity_id IF NOT EXISTS ON (e:Entity) ASSERT e.id IS UNIQUE;"
cypher-shell -u neo4j -p osintpassword "CREATE INDEX entity_type IF NOT EXISTS FOR (e:Entity) ON (e.type);"
cypher-shell -u neo4j -p osintpassword "CREATE INDEX entity_value IF NOT EXISTS FOR (e:Entity) ON (e.value);"

echo "Neo4j initialization completed successfully."