#!/usr/bin/env python3

"""
Enhanced OSINT Data Correlation Engine
"""

import os
import sys
import json
import argparse
import logging
from datetime import datetime
from dotenv import load_dotenv
from typing import Dict, Any, Optional

# Performance libraries
import numpy as np
import pandas as pd
import networkx as nx
from pydantic import BaseModel, Field, ValidationError

# Neo4j integration
from py2neo import Graph, Node, Relationship
from neo4j import GraphDatabase

# Error tracking
import sentry_sdk

# Logging configuration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('/opt/osint/logs/correlator.log')
    ]
)
logger = logging.getLogger('osint-correlator')

# Optional Sentry configuration
sentry_sdk.init(
    dsn="https://your-sentry-dsn-here",  # Replace with actual DSN
    traces_sample_rate=0.1
)

class EntityModel(BaseModel):
    """Standardized entity model for validation"""
    id: str
    type: str = Field(..., pattern=r'^[a-z_]+$')
    value: str
    source: str
    confidence: float = Field(default=0.7, ge=0, le=1)
    timestamp: str = Field(default_factory=lambda: datetime.now().isoformat())
    attributes: Optional[Dict[str, Any]] = None

class OSINTCorrelator:
    """Enhanced OSINT Data Correlation Engine"""

    def __init__(self):
        load_dotenv()
        self.neo4j_uri = os.getenv('NEO4J_URI', 'bolt://localhost:7687')
        self.neo4j_user = os.getenv('NEO4J_USER', 'neo4j')
        self.neo4j_password = os.getenv('NEO4J_PASSWORD', 'osintpassword')
        self.sentry_dsn = os.getenv('SENTRY_DSN')
        
        """Initialize correlator with Neo4j connection"""
        try:
            self.graph = GraphDatabase.driver(
                neo4j_uri, 
                auth=(neo4j_user, neo4j_password),
                encrypted=True
            )
            self.py2neo_graph = Graph(neo4j_uri, auth=(neo4j_user, neo4j_password))
            logger.info(f"Connected to Neo4j at {neo4j_uri}")
        except Exception as e:
            sentry_sdk.capture_exception(e)
            self.logger.error(f"Neo4j connection failed: {e}")
            raise

    def _setup_logging(self, log_level: str) -> logging.Logger:
        """Set up logging configuration.
        
        Args:
            log_level: Logging level as string
            
        Returns:
            Configured logger instance
        """
        logger = logging.getLogger("osint_correlator")
        logger.setLevel(log_level)
        
        # Create logs directory if it doesn't exist
        os.makedirs(self.log_dir, exist_ok=True)
        
        # Create file handler which logs messages
        log_file = os.path.join(self.log_dir, "correlator.log")
        fh = logging.FileHandler(log_file)
        fh.setLevel(log_level)
        
        # Create console handler with a higher log level
        ch = logging.StreamHandler()
        ch.setLevel(logging.ERROR)
        
        # Create formatter and add it to the handlers
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        fh.setFormatter(formatter)
        ch.setFormatter(formatter)
        
        # Add the handlers to the logger
        logger.addHandler(fh)
        logger.addHandler(ch)
        
        return logger

    def process_data_folder(
        self, 
        target_name: str, 
        batch_size: int = 1000
    ) -> bool:
        """Process data with batching"""
        target_dir = os.path.join(self.data_dir, "targets", target_name)
        
        if not os.path.exists(target_dir):
            self.logger.error(f"Target directory not found: {target_dir}")
            return False
        
        try:
            files = [
                os.path.join(root, f) 
                for root, _, files in os.walk(target_dir) 
                for f in files if f.endswith(('.json', '.csv', '.txt', '.xml'))
            ]
            
            self.logger.info(f"Found {len(files)} files to process")
            
            for i in range(0, len(files), batch_size):
                batch_files = files[i:i+batch_size]
                self._process_file_batch(batch_files, target_name)
            
            return True
        
        except Exception as e:
            sentry_sdk.capture_exception(e)
            self.logger.error(f"Error processing data folder: {e}")
            return False

    def _process_file_batch(self, files, target_name):
        """Process a batch of files"""
        with self.graph.session() as session:
            for file_path in files:
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    # Determine file type and process accordingly
                    if file_path.endswith('.json'):
                        data = json.loads(content)
                        self._process_json_data(session, data, target_name)
                    elif file_path.endswith('.csv'):
                        df = pd.read_csv(file_path)
                        self._process_csv_data(session, df, target_name)
                    
                except Exception as e:
                    self.logger.warning(f"Error processing {file_path}: {e}")
                    sentry_sdk.capture_exception(e)

    def _process_json_data(self, session, data, target_name):
        """Process JSON data and create Neo4j entities and relationships"""
        try:
            entities = data.get('entities', [])
            relationships = data.get('relationships', [])
            
            for entity_data in entities:
                # Validate entity data
                try:
                    entity = EntityModel(**entity_data)
                    self._create_entity_node(session, entity, target_name)
                except ValidationError as e:
                    self.logger.warning(f"Invalid entity: {e}")
            
            # Process relationships
            for rel_data in relationships:
                self._create_relationship(session, rel_data)
        
        except Exception as e:
            self.logger.error(f"JSON data processing error: {e}")
            sentry_sdk.capture_exception(e)

    def process_pentest_data(self, target_name):
        """Process penetration testing results"""
        pentest_dir = os.path.join(self.data_dir, "pentesting")
        
        if not os.path.exists(pentest_dir):
            return
        
        # Process SQL injection results
        sqli_dir = os.path.join(pentest_dir, "sqli")
        if os.path.exists(sqli_dir):
            self._process_sqli_results(sqli_dir, target_name)
        
        # Process brute force results
        bruteforce_dir = os.path.join(pentest_dir, "bruteforce")
        if os.path.exists(bruteforce_dir):
            self._process_bruteforce_results(bruteforce_dir, target_name)
        
        # Process SMB enumeration results
        smb_dir = os.path.join(pentest_dir, "smb")
        if os.path.exists(smb_dir):
            self._process_smb_results(smb_dir, target_name)

    def _create_entity_node(self, session, entity, target_name):
        """Create entity node in Neo4j"""
        create_node_query = """
        MERGE (t:Target {name: $target_name})
        MERGE (e:Entity {id: $entity_id})
        SET e.type = $entity_type, 
            e.value = $entity_value, 
            e.source = $entity_source,
            e.confidence = $entity_confidence,
            e.timestamp = $entity_timestamp
        MERGE (t)-[:CONTAINS]->(e)
        """
        
        session.run(create_node_query, {
            'target_name': target_name,
            'entity_id': entity.id,
            'entity_type': entity.type,
            'entity_value': entity.value,
            'entity_source': entity.source,
            'entity_confidence': entity.confidence,
            'entity_timestamp': entity.timestamp
        })

    def _create_relationship(self, session, rel_data):
        """Create relationships between entities"""
        # Implement relationship creation logic here
        pass

    def generate_graph_visualization(
        self, 
        target_name: str, 
        output_dir: Optional[str] = None
    ) -> Optional[str]:
        """Generate graph visualization for a target"""
        try:
            output_dir = output_dir or os.path.join('/opt/osint/data/reports', target_name)
            os.makedirs(output_dir, exist_ok=True)
            
            # Use existing graph visualization method from previous implementation
            # This is a placeholder for now
            return None
        
        except Exception as e:
            logger.error(f"Graph visualization failed: {e}")
            sentry_sdk.capture_exception(e)
            return None

def main():
    """Main CLI function"""
    parser = argparse.ArgumentParser(description='OSINT Data Correlation Engine')
    parser.add_argument('-t', '--target', required=True, help='Target to analyze')
    parser.add_argument('-d', '--data-dir', default='/opt/osint/data', help='Data directory')
    parser.add_argument('-v', '--visualize', action='store_true', help='Generate graph visualization')
    
    args = parser.parse_args()

    try:
        correlator = OSINTCorrelator()
        success = correlator.process_data_folder(args.target, args.data_dir)
        
        if not success:
            logger.error(f"Failed to process data for target: {args.target}")
            sys.exit(1)
        
        if args.visualize:
            viz_file = correlator.generate_graph_visualization(args.target)
            print(f"Visualization saved to: {viz_file}")
        
        sys.exit(0)
    
    except Exception as e:
        logger.error(f"Unhandled error: {e}")
        sentry_sdk.capture_exception(e)
        sys.exit(1)

if __name__ == "__main__":
    main()