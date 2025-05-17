#!/usr/bin/env python3

"""
OSINT Data Correlation Engine
Provides a lightweight Python alternative to the Rust correlator
"""

import os
import sys
import json
import argparse
import logging
from datetime import datetime
import re
import ipaddress
import hashlib
import uuid
import py2neo
from py2neo import Graph, Node, Relationship

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(os.path.join(os.path.dirname(__file__), 'correlator.log'))
    ]
)
logger = logging.getLogger('osint-correlator')

# Default paths
DEFAULT_DATA_DIR = "/opt/osint/data"
DEFAULT_NEO4J_URI = "bolt://localhost:7687"
DEFAULT_NEO4J_USER = "neo4j"
DEFAULT_NEO4J_PASSWORD = "osint_password"

# Entity and relationship types
ENTITY_TYPES = [
    "domain", "subdomain", "ip_address", "email", "username", 
    "person", "organization", "phone", "url", "certificate",
    "social_media", "file", "hash"
]

RELATIONSHIP_TYPES = [
    "contains", "resolves_to", "belongs_to", "communicates_with",
    "hosts", "redirects_to", "related_to", "same_as", "part_of",
    "uses", "has_record", "has_vuln", "owns", "registrant", 
    "admin_contact", "tech_contact", "nameserver"
]

class OSINTCorrelator:
    """OSINT Data correlation engine that connects to Neo4j"""
    
    def __init__(self, neo4j_uri=DEFAULT_NEO4J_URI, 
                 neo4j_user=DEFAULT_NEO4J_USER, 
                 neo4j_password=DEFAULT_NEO4J_PASSWORD):
        """Initialize the correlator with Neo4j connection"""
        self.neo4j_uri = neo4j_uri
        self.neo4j_user = neo4j_user
        self.neo4j_password = neo4j_password
        self.graph = None
        self._connect_to_neo4j()
    
    def _connect_to_neo4j(self):
        """Connect to Neo4j database"""
        try:
            self.graph = Graph(self.neo4j_uri, auth=(self.neo4j_user, self.neo4j_password))
            logger.info(f"Connected to Neo4j at {self.neo4j_uri}")
        except Exception as e:
            logger.error(f"Failed to connect to Neo4j: {e}")
            raise
    
    def process_data_folder(self, target_name, data_dir=DEFAULT_DATA_DIR):
        """Process all OSINT data for a target from data folder"""
        target_dir = os.path.join(data_dir, "targets", target_name)
        
        if not os.path.exists(target_dir):
            logger.error(f"Target directory not found: {target_dir}")
            return False
        
        # Create target node
        target_node = self._create_target_node(target_name)
        
        # Process each tool's data directory
        processed_files = 0
        for root, dirs, files in os.walk(target_dir):
            for file in files:
                if file.endswith(('.json', '.xml', '.csv', '.txt')):
                    file_path = os.path.join(root, file)
                    tool_name = os.path.basename(os.path.dirname(file_path))
                    
                    try:
                        # Process based on file type
                        if file.endswith('.json'):
                            self._process_json_file(file_path, tool_name, target_node)
                        elif file.endswith('.csv'):
                            self._process_csv_file(file_path, tool_name, target_node)
                        elif file.endswith('.txt'):
                            self._process_text_file(file_path, tool_name, target_node)
                        elif file.endswith('.xml'):
                            self._process_xml_file(file_path, tool_name, target_node)
                        
                        processed_files += 1
                    except Exception as e:
                        logger.error(f"Error processing file {file_path}: {e}")
        
        logger.info(f"Processed {processed_files} files for target {target_name}")
        return processed_files > 0
    
    def _create_target_node(self, target_name):
        """Create or retrieve a target node"""
        target_node = Node("Target", name=target_name, 
                          created=datetime.now().isoformat())
        
        # Create if not exists using merge
        self.graph.merge(target_node, "Target", "name")
        return target_node
    
    def _process_json_file(self, file_path, tool_name, target_node):
        """Process a JSON file with OSINT data"""
        try:
            with open(file_path, 'r') as f:
                data = json.load(f)
            
            # Handle different JSON formats
            if isinstance(data, list):
                for item in data:
                    self._process_entity(item, tool_name, target_node)
            elif isinstance(data, dict):
                # Check if it's a standard scan result format
                if 'entities' in data and isinstance(data['entities'], list):
                    for entity in data['entities']:
                        self._process_entity(entity, tool_name, target_node)
                    
                    # Process relationships if present
                    if 'relationships' in data and isinstance(data['relationships'], list):
                        for rel in data['relationships']:
                            self._process_relationship(rel, tool_name)
                else:
                    # Treat as a single entity
                    self._process_entity(data, tool_name, target_node)
        except json.JSONDecodeError:
            logger.error(f"Invalid JSON in file: {file_path}")
    
    def _process_csv_file(self, file_path, tool_name, target_node):
        """Process a CSV file with OSINT data"""
        import csv
        
        try:
            with open(file_path, 'r', newline='') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    # Convert CSV row to entity
                    self._process_entity(row, tool_name, target_node)
        except Exception as e:
            logger.error(f"Error processing CSV file {file_path}: {e}")
    
    def _process_text_file(self, file_path, tool_name, target_node):
        """Process a text file, extracting entities using regex"""
        try:
            with open(file_path, 'r') as f:
                content = f.read()
            
            # Extract entities using regex
            domains = self._extract_domains(content)
            ips = self._extract_ips(content)
            emails = self._extract_emails(content)
            
            # Create entities
            for domain in domains:
                entity = {
                    "type": "domain",
                    "value": domain,
                    "source": tool_name,
                    "confidence": 0.7,
                }
                self._process_entity(entity, tool_name, target_node)
            
            for ip in ips:
                entity = {
                    "type": "ip_address",
                    "value": ip,
                    "source": tool_name,
                    "confidence": 0.7,
                }
                self._process_entity(entity, tool_name, target_node)
            
            for email in emails:
                entity = {
                    "type": "email",
                    "value": email,
                    "source": tool_name,
                    "confidence": 0.7,
                }
                self._process_entity(entity, tool_name, target_node)
        except Exception as e:
            logger.error(f"Error processing text file {file_path}: {e}")
    
    def _process_xml_file(self, file_path, tool_name, target_node):
        """Process an XML file (typically from Nmap or similar tools)"""
        try:
            import xml.etree.ElementTree as ET
            
            # Parse XML
            tree = ET.parse(file_path)
            root = tree.getroot()
            
            # Handle Nmap XML
            if root.tag == 'nmaprun':
                # Process hosts
                for host in root.findall('.//host'):
                    # Get IP address
                    ip_addr = host.find('.//address[@addrtype="ipv4"]')
                    if ip_addr is not None:
                        ip = ip_addr.get('addr')
                        ip_entity = {
                            "type": "ip_address",
                            "value": ip,
                            "source": tool_name,
                            "confidence": 0.9,
                        }
                        ip_node = self._process_entity(ip_entity, tool_name, target_node)
                        
                        # Process ports
                        for port in host.findall('.//port'):
                            if port.find('.//state').get('state') == 'open':
                                port_num = port.get('portid')
                                protocol = port.get('protocol')
                                
                                # Get service info if available
                                service = port.find('.//service')
                                if service is not None:
                                    service_name = service.get('name', '')
                                    product = service.get('product', '')
                                    version = service.get('version', '')
                                    
                                    service_entity = {
                                        "type": "service",
                                        "value": f"{service_name}",
                                        "port": port_num,
                                        "protocol": protocol,
                                        "product": product,
                                        "version": version,
                                        "source": tool_name,
                                        "confidence": 0.9,
                                    }
                                    service_node = self._process_entity(
                                        service_entity, tool_name, target_node)
                                    
                                    # Create relationship between IP and service
                                    if ip_node and service_node:
                                        rel_data = {
                                            "source_id": ip_node["id"],
                                            "target_id": service_node["id"],
                                            "type": "hosts",
                                            "source": tool_name,
                                            "confidence": 0.9,
                                            "attributes": {
                                                "port": port_num,
                                                "protocol": protocol
                                            }
                                        }
                                        self._process_relationship(rel_data, tool_name)
        except Exception as e:
            logger.error(f"Error processing XML file {file_path}: {e}")
    
    def _process_entity(self, entity_data, source, target_node):
        """Process and store an entity in Neo4j"""
        # Extract entity type and value
        entity_type = entity_data.get('type', self._infer_entity_type(entity_data))
        
        if not entity_type or entity_type not in ENTITY_TYPES:
            logger.warning(f"Unknown entity type: {entity_type}")
            entity_type = "unknown"
        
        # Get or infer value
        value = entity_data.get('value', self._extract_entity_value(entity_data, entity_type))
        
        if not value:
            logger.warning(f"Could not determine value for entity: {entity_data}")
            return None
        
        # Generate ID if not present
        entity_id = entity_data.get('id', f"{entity_type}:{value}")
        
        # Extract other attributes
        confidence = float(entity_data.get('confidence', 0.7))
        timestamp = entity_data.get('timestamp', datetime.now().isoformat())
        
        # Create attributes dictionary
        attributes = entity_data.get('attributes', {})
        
        # If attributes not explicitly defined, copy all other fields
        if not attributes:
            attributes = {k: v for k, v in entity_data.items() 
                         if k not in ['id', 'type', 'value', 'source', 'confidence', 'timestamp']}
        
        # Create Neo4j node
        node_labels = ["Entity", entity_type.capitalize()]
        node = Node(*node_labels, 
                   id=entity_id,
                   type=entity_type,
                   value=value,
                   source=source,
                   confidence=confidence,
                   timestamp=timestamp,
                   **attributes)
        
        # Merge node (create if not exists, update if exists)
        self.graph.merge(node, "Entity", "id")
        
        # Create relationship to target
        rel = Relationship(target_node, "CONTAINS", node, 
                          timestamp=timestamp,
                          source=source)
        self.graph.merge(rel)
        
        return {"id": entity_id, "node": node}
    
    def _process_relationship(self, rel_data, source):
        """Process and store a relationship between entities"""
        # Extract relationship data
        source_id = rel_data.get('source_id')
        target_id = rel_data.get('target_id')
        rel_type = rel_data.get('type', 'related_to').upper()
        
        if not source_id or not target_id:
            logger.warning(f"Missing source or target ID in relationship: {rel_data}")
            return None
        
        # Get attributes
        confidence = float(rel_data.get('confidence', 0.7))
        timestamp = rel_data.get('timestamp', datetime.now().isoformat())
        attributes = rel_data.get('attributes', {})
        
        # Query source and target nodes
        source_node = self.graph.nodes.match("Entity", id=source_id).first()
        target_node = self.graph.nodes.match("Entity", id=target_id).first()
        
        if not source_node or not target_node:
            logger.warning(f"Source or target node not found for relationship: {rel_data}")
            return None
        
        # Create relationship
        rel = Relationship(source_node, rel_type, target_node,
                          source=source,
                          confidence=confidence,
                          timestamp=timestamp,
                          **attributes)
        
        # Store relationship
        self.graph.merge(rel)
        return rel
    
    def _infer_entity_type(self, entity_data):
        """Infer entity type from data"""
        # Check common fields
        if 'domain' in entity_data or 'hostname' in entity_data:
            return 'domain'
        elif 'ip' in entity_data or 'ipv4' in entity_data or 'ipv6' in entity_data:
            return 'ip_address'
        elif 'email' in entity_data:
            return 'email'
        elif 'username' in entity_data or 'user' in entity_data:
            return 'username'
        elif 'phone' in entity_data or 'number' in entity_data:
            return 'phone'
        
        # Check value field if present
        value = entity_data.get('value', '')
        if isinstance(value, str):
            if self._is_domain(value):
                return 'domain'
            elif self._is_ip(value):
                return 'ip_address'
            elif self._is_email(value):
                return 'email'
        
        return 'unknown'
    
    def _extract_entity_value(self, entity_data, entity_type):
        """Extract the main value of an entity based on its type"""
        # Check for 'value' field first
        if 'value' in entity_data:
            return entity_data['value']
        
        # Type-specific extraction
        if entity_type == 'domain':
            for field in ['domain', 'hostname', 'host', 'name']:
                if field in entity_data:
                    return entity_data[field]
        elif entity_type == 'ip_address':
            for field in ['ip', 'ipv4', 'ipv6', 'address']:
                if field in entity_data:
                    return entity_data[field]
        elif entity_type == 'email':
            if 'email' in entity_data:
                return entity_data['email']
        elif entity_type == 'username':
            for field in ['username', 'user', 'account']:
                if field in entity_data:
                    return entity_data[field]
        elif entity_type == 'phone':
            for field in ['phone', 'number', 'phoneNumber']:
                if field in entity_data:
                    return entity_data[field]
        
        # Fallback to first string value
        for key, value in entity_data.items():
            if isinstance(value, str) and value:
                return value
        
        return None
    
    def _is_domain(self, value):
        """Check if string is a domain name"""
        domain_pattern = r'^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'
        return bool(re.match(domain_pattern, value))
    
    def _is_ip(self, value):
        """Check if string is an IP address"""
        try:
            ipaddress.ip_address(value)
            return True
        except ValueError:
            return False
    
    def _is_email(self, value):
        """Check if string is an email address"""
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        return bool(re.match(email_pattern, value))
    
    def _extract_domains(self, text):
        """Extract domain names from text"""
        domain_pattern = r'\b([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}\b'
        return set(re.findall(domain_pattern, text))
    
    def _extract_ips(self, text):
        """Extract IP addresses from text"""
        ip_pattern = r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b'
        return set(re.findall(ip_pattern, text))
    
    def _extract_emails(self, text):
        """Extract email addresses from text"""
        email_pattern = r'\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b'
        return set(re.findall(email_pattern, text))
    
    def generate_graph_visualization(self, target_name, output_dir=None):
        """Generate a visualization of the data graph"""
        if not output_dir:
            output_dir = os.path.join(DEFAULT_DATA_DIR, "reports", target_name)
        
        # Create output directory if it doesn't exist
        os.makedirs(output_dir, exist_ok=True)
        
        # Generate timestamp
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # Generate filename
        output_file = os.path.join(output_dir, f"{target_name}_graph_{timestamp}.html")
        
        # Query for target's entities
        query = """
        MATCH (t:Target {name: $target_name})-[:CONTAINS]->(e:Entity)
        OPTIONAL MATCH (e)-[r]-(related)
        RETURN e, r, related
        """
        
        result = self.graph.run(query, target_name=target_name)
        data = result.data()
        
        # Generate visualization using vis.js
        nodes = {}
        edges = []
        
        for record in data:
            # Process entity
            e = record['e']
            if e and e.identity not in nodes:
                nodes[e.identity] = {
                    'id': e.identity,
                    'label': f"{e['value']}",
                    'title': f"Type: {e['type']}<br>Value: {e['value']}<br>Source: {e['source']}",
                    'group': e['type']
                }
            
            # Process relationship
            r = record['r']
            related = record['related']
            
            if r and related and related.identity not in nodes:
                nodes[related.identity] = {
                    'id': related.identity,
                    'label': related.get('value', 'Unknown'),
                    'title': f"Type: {related.get('type', 'Unknown')}<br>Value: {related.get('value', 'Unknown')}",
                    'group': related.get('type', 'unknown')
                }
            
            if r and related:
                edges.append({
                    'from': r.start_node.identity,
                    'to': r.end_node.identity,
                    'label': r.type,
                    'title': f"Type: {r.type}<br>Source: {r.get('source', 'Unknown')}"
                })
        
        # Generate HTML
        html = self._generate_html_visualization(list(nodes.values()), edges, target_name)
        
        # Write HTML to file
        with open(output_file, 'w') as f:
            f.write(html)
        
        logger.info(f"Graph visualization saved to {output_file}")
        return output_file
    
    def _generate_html_visualization(self, nodes, edges, target_name):
        """Generate HTML with vis.js visualization"""
        html = f"""<!DOCTYPE html>
<html>
<head>
    <title>OSINT Graph: {target_name}</title>
    <script type="text/javascript" src="https://unpkg.com/vis-network/standalone/umd/vis-network.min.js"></script>
    <style type="text/css">
        #network {{
            width: 100%;
            height: 800px;
            border: 1px solid lightgray;
        }}
        body {{
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
        }}
        .header {{
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 1px solid #ccc;
        }}
        .footer {{
            margin-top: 20px;
            padding-top: 10px;
            border-top: 1px solid #ccc;
            font-size: 0.8em;
            color: #666;
        }}
    </style>
</head>
<body>
    <div class="header">
        <h1>OSINT Graph: {target_name}</h1>
        <p>Generated on {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}</p>
    </div>
    
    <div id="network"></div>
    
    <div class="footer">
        <p>OSINT Command Center - Graph Visualization</p>
    </div>
    
    <script type="text/javascript">
        // Create nodes and edges
        var nodes = new vis.DataSet({json.dumps(nodes)});
        var edges = new vis.DataSet({json.dumps(edges)});
        
        // Create a network
        var container = document.getElementById('network');
        var data = {{
            nodes: nodes,
            edges: edges
        }};
        var options = {{
            nodes: {{
                shape: 'dot',
                size: 16,
                font: {{
                    size: 12,
                    face: 'Tahoma'
                }}
            }},
            edges: {{
                width: 0.15,
                color: {{
                    color: '#333333',
                    highlight: '#000000'
                }},
                smooth: {{
                    type: 'continuous'
                }},
                arrows: 'to',
                font: {{
                    size: 10,
                    align: 'middle'
                }}
            }},
            physics: {{
                enabled: true,
                barnesHut: {{
                    gravitationalConstant: -8000,
                    centralGravity: 0.3,
                    springLength: 95,
                    springConstant: 0.04,
                    damping: 0.09
                }}
            }},
            groups: {{
                domain: {{
                    color: {{ background: '#97C2FC', border: '#2B7CE9' }}
                }},
                subdomain: {{
                    color: {{ background: '#B4E2FC', border: '#2B7CE9' }}
                }},
                ip_address: {{
                    color: {{ background: '#FB7E81', border: '#C70F1C' }}
                }},
                email: {{
                    color: {{ background: '#FFAA88', border: '#FF6600' }}
                }},
                username: {{
                    color: {{ background: '#7BE141', border: '#417E05' }}
                }},
                service: {{
                    color: {{ background: '#6E6EFD', border: '#0000FF' }}
                }},
                unknown: {{
                    color: {{ background: '#C2FABC', border: '#74D66A' }}
                }}
            }}
        }};
        var network = new vis.Network(container, data, options);
    </script>
</body>
</html>
"""
        return html
    
    def generate_report(self, target_name, output_dir=None):
        """Generate a comprehensive report for a target"""
        if not output_dir:
            output_dir = os.path.join(DEFAULT_DATA_DIR, "reports", target_name)
        
        # Create output directory if it doesn't exist
        os.makedirs(output_dir, exist_ok=True)
        
        # Generate timestamp
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # Generate filename
        output_file = os.path.join(output_dir, f"{target_name}_report_{timestamp}.html")
        
        # Query for target's entities
        query = """
        MATCH (t:Target {name: $target_name})-[:CONTAINS]->(e:Entity)
        RETURN e.type AS type, count(e) AS count
        ORDER BY count DESC
        """
        
        result = self.graph.run(query, target_name=target_name)
        type_counts = result.data()
        
        # Query for entity details by type
        entity_details = {}
        for type_info in type_counts:
            entity_type = type_info['type']
            
            # Query for entities of this type
            query = """
            MATCH (t:Target {name: $target_name})-[:CONTAINS]->(e:Entity)
            WHERE e.type = $entity_type
            RETURN e
            ORDER BY e.confidence DESC, e.value
            LIMIT 100
            """
            
            result = self.graph.run(query, target_name=target_name, entity_type=entity_type)
            entity_details[entity_type] = [dict(e) for e in result.data()]
        
        # Generate HTML
        html = self._generate_html_report(target_name, type_counts, entity_details)
        
        # Write HTML to file
        with open(output_file, 'w') as f:
            f.write(html)
        
        logger.info(f"Report saved to {output_file}")
        return output_file
    
    def _generate_html_report(self, target_name, type_counts, entity_details):
        """Generate HTML report"""
        # Create HTML content
        html = f"""<!DOCTYPE html>
<html>
<head>
    <title>OSINT Report: {target_name}</title>
    <style>
        body {{
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            color: #333;
        }}
        h1, h2, h3 {{
            color: #2c3e50;
        }}
        .container {{
            max-width: 1200px;
            margin: 0 auto;
        }}
        .header {{
            margin-bottom: 30px;
            padding-bottom: 10px;
            border-bottom: 1px solid #eee;
        }}
        .section {{
            margin-bottom: 30px;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 20px;
        }}
        th, td {{
            padding: 12px 15px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }}
        th {{
            background-color: #f8f9fa;
            font-weight: bold;
        }}
        tr:hover {{
            background-color: #f5f5f5;
        }}
        .summary-box {{
            background-color: #f8f9fa;
            border-radius: 5px;
            padding: 15px;
            margin-bottom: 20px;
        }}
        .footer {{
            margin-top: 30px;
            padding-top: 10px;
            border-top: 1px solid #eee;
            font-size: 0.8em;
            color: #777;
        }}
        .chart-container {{
            width: 600px;
            height: 400px;
            margin: 20px auto;
        }}
    </style>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>OSINT Analysis Report: {target_name}</h1>
            <p>Generated on {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}</p>
        </div>
        
        <div class="section">
            <h2>Executive Summary</h2>
            <div class="summary-box">
                <p>This report contains the findings from OSINT analysis of <strong>{target_name}</strong>.</p>
                <p>Total entities discovered: {sum(item['count'] for item in type_counts)}</p>
                <p>Entity types found: {len(type_counts)}</p>
            </div>
        </div>
        
        <div class="section">
            <h2>Entity Summary</h2>
            <div class="chart-container">
                <canvas id="entityChart"></canvas>
            </div>
            
            <table>
                <tr>
                    <th>Entity Type</th>
                    <th>Count</th>
                </tr>
        """
        
        # Add entity type counts to table
        for type_info in type_counts:
            html += f"""
                <tr>
                    <td>{type_info['type']}</td>
                    <td>{type_info['count']}</td>
                </tr>
            """
        
        html += """
            </table>
        </div>
        """
        
        # Add sections for each entity type
        for entity_type, entities in entity_details.items():
            if entities:
                html += f"""
        <div class="section">
            <h2>{entity_type.capitalize()} Entities</h2>
            <table>
                <tr>
                    <th>Value</th>
                    <th>Confidence</th>
                    <th>Source</th>
                </tr>
                """
                
                # Add entity details
                for entity in entities:
                    html += f"""
                <tr>
                    <td>{entity['e']['value']}</td>
                    <td>{entity['e'].get('confidence', 'N/A')}</td>
                    <td>{entity['e'].get('source', 'N/A')}</td>
                </tr>
                    """
                
                html += """
            </table>
        </div>
                """
        
        # Add footer and JavaScript for chart
        html += f"""
        <div class="footer">
            <p>OSINT Command Center - Analysis Report</p>
        </div>
    </div>
    
    <script>
        // Create chart for entity types
        var ctx = document.getElementById('entityChart').getContext('2d');
        var entityChart = new Chart(ctx, {{
            type: 'bar',
            data: {{
                labels: {json.dumps([item['type'] for item in type_counts])},
                datasets: [{{
                    label: 'Entity Count',
                    data: {json.dumps([item['count'] for item in type_counts])},
                    backgroundColor: [
                        'rgba(54, 162, 235, 0.5)',
                        'rgba(255, 99, 132, 0.5)',
                        'rgba(255, 206, 86, 0.5)',
                        'rgba(75, 192, 192, 0.5)',
                        'rgba(153, 102, 255, 0.5)',
                        'rgba(255, 159, 64, 0.5)',
                        'rgba(199, 199, 199, 0.5)'
                    ],
                    borderColor: [
                        'rgba(54, 162, 235, 1)',
                        'rgba(255, 99, 132, 1)',
                        'rgba(255, 206, 86, 1)',
                        'rgba(75, 192, 192, 1)',
                        'rgba(153, 102, 255, 1)',
                        'rgba(255, 159, 64, 1)',
                        'rgba(199, 199, 199, 1)'
                    ],
                    borderWidth: 1
                }}]
            }},
            options: {{
                responsive: true,
                scales: {{
                    y: {{
                        beginAtZero: true
                    }}
                }}
            }}
        }});
    </script>
</body>
</html>
"""
        
        return html

def main():
    """Main function to run the correlator from command line"""
    parser = argparse.ArgumentParser(description='OSINT Data Correlation Engine')
    parser.add_argument('-t', '--target', required=True, help='Target to analyze')
    parser.add_argument('-d', '--data-dir', default=DEFAULT_DATA_DIR, help='Data directory')
    parser.add_argument('--neo4j-uri', default=DEFAULT_NEO4J_URI, help='Neo4j URI')
    parser.add_argument('--neo4j-user', default=DEFAULT_NEO4J_USER, help='Neo4j username')
    parser.add_argument('--neo4j-password', default=DEFAULT_NEO4J_PASSWORD, help='Neo4j password')
    parser.add_argument('-v', '--visualize', action='store_true', help='Generate graph visualization')
    parser.add_argument('-r', '--report', action='store_true', help='Generate HTML report')
    
    args = parser.parse_args()
    
    try:
        # Initialize correlator
        correlator = OSINTCorrelator(
            neo4j_uri=args.neo4j_uri,
            neo4j_user=args.neo4j_user,
            neo4j_password=args.neo4j_password
        )
        
        # Process data
        success = correlator.process_data_folder(args.target, args.data_dir)
        
        if not success:
            logger.error(f"No data processed for target: {args.target}")
            return 1
        
        # Generate visualization if requested
        if args.visualize:
            viz_file = correlator.generate_graph_visualization(args.target)
            print(f"Graph visualization saved to: {viz_file}")
        
        # Generate report if requested
        if args.report:
            report_file = correlator.generate_report(args.target)
            print(f"Report saved to: {report_file}")
        
        return 0
    
    except Exception as e:
        logger.error(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    sys.exit(main())