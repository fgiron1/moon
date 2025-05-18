# Network visualization template for Neo4j
MATCH (n)
OPTIONAL MATCH (n)-[r]->(m)
RETURN n, r, m