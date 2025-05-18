#!/usr/bin/env python3

"""
OSINT Report Generator - Creates reports from standardized OSINT data
Loads templates from external files rather than hardcoding HTML
"""

import os
import sys
import json
import argparse
import logging
import csv
import re
import uuid
import datetime
from pathlib import Path
from jinja2 import Template, Environment, FileSystemLoader
import matplotlib
matplotlib.use('Agg')  # Use non-interactive backend
import matplotlib.pyplot as plt
import base64
from io import BytesIO
from collections import Counter, defaultdict

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('osint-report-generator')

class OSINTReportGenerator:
    """Generates reports from standardized OSINT data"""
    
    def __init__(self, data_dir="/opt/osint/data"):
        """Initialize the report generator with data directory"""
        self.data_dir = Path(data_dir)
        self.standardized_dir = self.data_dir / "standardized"
        self.reports_dir = self.data_dir / "reports"
        
        # Create reports directory if it doesn't exist
        os.makedirs(self.reports_dir, exist_ok=True)
        
        # Set up Jinja2 environment
        template_dir = Path(__file__).parent / "templates"
        if not template_dir.exists():
            logger.error(f"Template directory not found: {template_dir}")
            logger.error("Please create the templates directory with the required templates")
            raise FileNotFoundError(f"Template directory not found: {template_dir}")
            
        self.jinja_env = Environment(loader=FileSystemLoader(template_dir))
    
    def generate_report(self, target_name, format="html", output_file=None):
        """Generate a report for the target in the specified format"""
        # Get standardized data
        target_data_path = self.standardized_dir / target_name / f"{target_name}_standardized.json"
        
        if not target_data_path.exists():
            logger.error(f"No standardized data found for target: {target_name}")
            return False
        
        # Load standardized data
        with open(target_data_path, 'r') as f:
            try:
                data = json.load(f)
            except json.JSONDecodeError:
                logger.error(f"Invalid JSON in standardized data file: {target_data_path}")
                return False
        
        # Create report directory if it doesn't exist
        target_report_dir = self.reports_dir / target_name
        os.makedirs(target_report_dir, exist_ok=True)
        
        # Set default output file if not specified
        if not output_file:
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            output_file = target_report_dir / f"{target_name}_report_{timestamp}.{format}"
        
        # Generate report based on format
        if format == "html":
            success = self._generate_html_report(data, output_file)
        elif format == "csv":
            success = self._generate_csv_report(data, output_file)
        elif format == "json":
            success = self._generate_json_report(data, output_file)
        else:
            logger.error(f"Unsupported report format: {format}")
            return False
        
        if success:
            logger.info(f"Report generated successfully: {output_file}")
            return True
        else:
            logger.error(f"Failed to generate {format} report")
            return False
    
    def _generate_html_report(self, data, output_file):
        """Generate an HTML report from the standardized data using external template"""
        try:
            # Process data for the template
            report_data = self._process_data_for_report(data)
            
            # Get the HTML template
            try:
                template = self.jinja_env.get_template("html_report.html")
            except Exception as e:
                logger.error(f"Error loading HTML template: {e}")
                return False
            
            # Render the template with the data
            html_content = template.render(**report_data)
            
            # Write the report to a file
            with open(output_file, 'w') as f:
                f.write(html_content)
            
            return True
        except Exception as e:
            logger.error(f"Error generating HTML report: {e}")
            return False
    
    def _generate_csv_report(self, data, output_file):
        """Generate a CSV report from the standardized data"""
        try:
            # Open the output file
            with open(output_file, 'w', newline='') as f:
                writer = csv.writer(f)
                
                # Write header
                writer.writerow(['Type', 'Value', 'Source', 'Confidence', 'Attributes'])
                
                # Write entity data
                for entity in data.get('entities', []):
                    attributes = json.dumps(entity.get('attributes', {}))
                    source = entity.get('source', '')
                    if not source and 'sources' in entity:
                        source = ', '.join(entity.get('sources', []))
                    
                    writer.writerow([
                        entity.get('type', ''),
                        entity.get('value', ''),
                        source,
                        entity.get('confidence', ''),
                        attributes
                    ])
                
                # Add a separator
                writer.writerow(['', '', '', '', ''])
                writer.writerow(['Relationship Type', 'Source Entity', 'Target Entity', 'Confidence', 'Attributes'])
                
                # Write relationship data
                for rel in data.get('relationships', []):
                    attributes = json.dumps(rel.get('attributes', {}))
                    
                    writer.writerow([
                        rel.get('type', ''),
                        rel.get('source_id', ''),
                        rel.get('target_id', ''),
                        rel.get('confidence', ''),
                        attributes
                    ])
            
            return True
        except Exception as e:
            logger.error(f"Error generating CSV report: {e}")
            return False
    
    def _generate_json_report(self, data, output_file):
        """Generate a JSON report from the standardized data"""
        try:
            # Write the standardized data to a file
            with open(output_file, 'w') as f:
                json.dump(data, f, indent=2)
            
            return True
        except Exception as e:
            logger.error(f"Error generating JSON report: {e}")
            return False
    
    def _process_data_for_report(self, data):
        """Process the standardized data for the report"""
        report_data = {
            'target': data.get('target', ''),
            'timestamp': data.get('timestamp', ''),
            'generated_at': datetime.datetime.now().isoformat(),
            'total_entities': len(data.get('entities', [])),
            'total_relationships': len(data.get('relationships', [])),
            'tools_used': data.get('summary', {}).get('tools', []),
        }
        
        # Group entities by type
        entities_by_type = defaultdict(list)
        for entity in data.get('entities', []):
            entity_type = entity.get('type', 'unknown')
            entities_by_type[entity_type].append(entity)
        
        report_data['entities_by_type'] = dict(entities_by_type)
        
        # Sort entities by confidence
        for entity_type, entities in report_data['entities_by_type'].items():
            report_data['entities_by_type'][entity_type] = sorted(
                entities, 
                key=lambda x: x.get('confidence', 0), 
                reverse=True
            )
        
        # Generate entity type distribution chart
        entity_type_counts = {k: len(v) for k, v in entities_by_type.items()}
        report_data['entity_type_chart'] = self._generate_entity_type_chart(entity_type_counts)
        
        # Process relationships
        report_data['relationships'] = data.get('relationships', [])
        
        # Group relationships by type
        relationships_by_type = defaultdict(list)
        for rel in data.get('relationships', []):
            rel_type = rel.get('type', 'unknown')
            relationships_by_type[rel_type].append(rel)
        
        report_data['relationships_by_type'] = dict(relationships_by_type)
        
        # Generate relationship type distribution chart
        rel_type_counts = {k: len(v) for k, v in relationships_by_type.items()}
        report_data['relationship_type_chart'] = self._generate_relationship_type_chart(rel_type_counts)
        
        return report_data
    
    def _generate_entity_type_chart(self, entity_type_counts):
        """Generate a chart showing the distribution of entity types"""
        if not entity_type_counts:
            return None
        
        try:
            # Create figure
            plt.figure(figsize=(10, 6))
            
            # Sort types by count
            sorted_items = sorted(entity_type_counts.items(), key=lambda x: x[1], reverse=True)
            labels, values = zip(*sorted_items)
            
            # Create bar chart
            plt.bar(labels, values)
            plt.title('Entity Type Distribution')
            plt.xlabel('Entity Type')
            plt.ylabel('Count')
            plt.xticks(rotation=45, ha='right')
            plt.tight_layout()
            
            # Save chart to memory
            buffer = BytesIO()
            plt.savefig(buffer, format='png')
            buffer.seek(0)
            
            # Convert to base64 for embedding in HTML
            image_base64 = base64.b64encode(buffer.getvalue()).decode('utf-8')
            plt.close()
            
            return f"data:image/png;base64,{image_base64}"
        except Exception as e:
            logger.error(f"Error generating entity type chart: {e}")
            return None
    
    def _generate_relationship_type_chart(self, rel_type_counts):
        """Generate a chart showing the distribution of relationship types"""
        if not rel_type_counts:
            return None
        
        try:
            # Create figure
            plt.figure(figsize=(10, 6))
            
            # Sort types by count
            sorted_items = sorted(rel_type_counts.items(), key=lambda x: x[1], reverse=True)
            labels, values = zip(*sorted_items)
            
            # Create bar chart
            plt.bar(labels, values)
            plt.title('Relationship Type Distribution')
            plt.xlabel('Relationship Type')
            plt.ylabel('Count')
            plt.xticks(rotation=45, ha='right')
            plt.tight_layout()
            
            # Save chart to memory
            buffer = BytesIO()
            plt.savefig(buffer, format='png')
            buffer.seek(0)
            
            # Convert to base64 for embedding in HTML
            image_base64 = base64.b64encode(buffer.getvalue()).decode('utf-8')
            plt.close()
            
            return f"data:image/png;base64,{image_base64}"
        except Exception as e:
            logger.error(f"Error generating relationship type chart: {e}")
            return None

def main():
    parser = argparse.ArgumentParser(description='OSINT Report Generator')
    parser.add_argument('-t', '--target', required=True, help='Target to generate report for')
    parser.add_argument('-f', '--format', default='html', choices=['html', 'csv', 'json'], help='Report format')
    parser.add_argument('-o', '--output', help='Output file path')
    parser.add_argument('-d', '--data-dir', default='/opt/osint/data', help='Data directory')
    
    args = parser.parse_args()
    
    report_generator = OSINTReportGenerator(args.data_dir)
    report_generator.generate_report(args.target, args.format, args.output)

if __name__ == "__main__":
    main()