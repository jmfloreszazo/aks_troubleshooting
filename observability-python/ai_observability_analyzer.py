#!/usr/bin/env python3
"""
AI-Powered Observability Insights Generator
============================================

This script extracts error patterns from Loki logs and Prometheus metrics,
then uses Azure OpenAI to generate intelligent troubleshooting insights.

Author: GitHub Copilot
Project: AKS Jenkins Spot Workers + AI Observability
"""

import os
import json
import asyncio
import aiohttp
import requests
import pandas as pd
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
from dotenv import load_dotenv
from openai import AzureOpenAI
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class ObservabilityAnalyzer:
    """Main class for AI-powered observability analysis"""
    
    def __init__(self):
        """Initialize the analyzer with configuration"""
        load_dotenv()
        
        # Azure OpenAI Configuration
        self.openai_client = AzureOpenAI(
            api_key=os.getenv("AZURE_OPENAI_API_KEY"),
            api_version=os.getenv("AZURE_OPENAI_API_VERSION", "2024-02-15-preview"),
            azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT")
        )
        self.deployment_name = os.getenv("AZURE_OPENAI_DEPLOYMENT_NAME", "gpt-4")
        
        # Observability Stack Configuration
        self.loki_endpoint = os.getenv("LOKI_ENDPOINT")
        self.prometheus_endpoint = os.getenv("PROMETHEUS_ENDPOINT")
        self.grafana_endpoint = os.getenv("GRAFANA_ENDPOINT")
        
        # Analysis Configuration
        self.query_interval = int(os.getenv("QUERY_INTERVAL_MINUTES", 5))
        self.max_log_entries = int(os.getenv("MAX_LOG_ENTRIES", 100))
        self.analysis_hours = int(os.getenv("ANALYSIS_HISTORY_HOURS", 1))
        
        # Output Configuration
        self.output_dir = os.getenv("OUTPUT_DIR", "./insights")
        self.generate_markdown = os.getenv("GENERATE_MARKDOWN", "true").lower() == "true"
        
        # Ensure output directory exists
        os.makedirs(self.output_dir, exist_ok=True)

    async def query_loki_errors(self) -> List[Dict[str, Any]]:
        """Extract error and warning logs from Loki"""
        
        # Calculate time range for analysis
        end_time = datetime.now()
        start_time = end_time - timedelta(hours=self.analysis_hours)
        
        # Loki queries for different error patterns
        error_queries = [
            # Jenkins Master Errors
            '{kubernetes_namespace_name="jenkins-master"} |~ "(?i)(error|exception|failed|timeout)"',
            
            # Jenkins Workers Errors  
            '{kubernetes_namespace_name="jenkins-workers"} |~ "(?i)(error|exception|failed|crash|killed)"',
            
            # Spot Workers Specific Issues
            '{kubernetes_namespace_name="jenkins-workers"} |= "spot" |~ "(?i)(evicted|preempted|terminated)"',
            
            # Kubernetes System Errors
            '{kubernetes_namespace_name=~"kube-.*"} |~ "(?i)(error|warning|failed)"',
            
            # Observability Stack Errors
            '{kubernetes_namespace_name=~"(loki|prometheus|grafana).*"} |~ "(?i)(error|warning|failed)"',
            
            # General Warning Patterns
            '{kubernetes_namespace_name!=""} |~ "(?i)(warning|warn|deprecated)"'
        ]
        
        all_logs = []
        
        for query in error_queries:
            try:
                url = f"{self.loki_endpoint}/loki/api/v1/query_range"
                params = {
                    'query': query,
                    'start': int(start_time.timestamp() * 1_000_000_000),  # nanoseconds
                    'end': int(end_time.timestamp() * 1_000_000_000),
                    'limit': self.max_log_entries,
                    'direction': 'backward'
                }
                
                async with aiohttp.ClientSession() as session:
                    async with session.get(url, params=params) as response:
                        if response.status == 200:
                            data = await response.json()
                            
                            if data.get('status') == 'success':
                                results = data.get('data', {}).get('result', [])
                                
                                for stream in results:
                                    labels = stream.get('stream', {})
                                    values = stream.get('values', [])
                                    
                                    for timestamp, log_line in values:
                                        all_logs.append({
                                            'timestamp': datetime.fromtimestamp(int(timestamp) / 1_000_000_000),
                                            'namespace': labels.get('kubernetes_namespace_name', 'unknown'),
                                            'pod': labels.get('kubernetes_pod_name', 'unknown'),
                                            'container': labels.get('kubernetes_container_name', 'unknown'),
                                            'log_line': log_line,
                                            'query_type': query,
                                            'severity': self._classify_severity(log_line)
                                        })
                        else:
                            logger.warning(f"Loki query failed with status {response.status}")
                            
            except Exception as e:
                logger.error(f"Error querying Loki: {e}")
                continue
        
        logger.info(f"Extracted {len(all_logs)} log entries from Loki")
        return sorted(all_logs, key=lambda x: x['timestamp'], reverse=True)

    async def query_prometheus_metrics(self) -> List[Dict[str, Any]]:
        """Extract critical metrics from Prometheus"""
        
        # Prometheus queries for key metrics
        metric_queries = [
            # High CPU Usage
            ('high_cpu', 'rate(container_cpu_usage_seconds_total[5m]) * 100 > 80'),
            
            # High Memory Usage
            ('high_memory', 'container_memory_usage_bytes / container_spec_memory_limit_bytes * 100 > 80'),
            
            # Pod Restart Count
            ('pod_restarts', 'increase(kube_pod_container_status_restarts_total[1h]) > 0'),
            
            # Jenkins Queue Length
            ('jenkins_queue', 'jenkins_queue_size_value > 5'),
            
            # Spot Instance Interruptions
            ('spot_interruptions', 'increase(kube_node_status_condition{condition="Ready",status="False"}[1h])'),
            
            # Disk Usage
            ('disk_usage', 'node_filesystem_avail_bytes / node_filesystem_size_bytes * 100 < 20'),
            
            # Failed Job Rate
            ('failed_jobs', 'rate(jenkins_job_failure_total[5m]) > 0.1')
        ]
        
        all_metrics = []
        
        for metric_name, query in metric_queries:
            try:
                url = f"{self.prometheus_endpoint}/api/v1/query"
                params = {'query': query}
                
                async with aiohttp.ClientSession() as session:
                    async with session.get(url, params=params) as response:
                        if response.status == 200:
                            data = await response.json()
                            
                            if data.get('status') == 'success':
                                results = data.get('data', {}).get('result', [])
                                
                                for result in results:
                                    metric = result.get('metric', {})
                                    value = result.get('value', [None, '0'])
                                    
                                    all_metrics.append({
                                        'timestamp': datetime.now(),
                                        'metric_name': metric_name,
                                        'query': query,
                                        'value': float(value[1]) if len(value) > 1 else 0,
                                        'labels': metric,
                                        'severity': self._classify_metric_severity(metric_name, float(value[1]) if len(value) > 1 else 0)
                                    })
                        else:
                            logger.warning(f"Prometheus query failed with status {response.status}")
                            
            except Exception as e:
                logger.error(f"Error querying Prometheus: {e}")
                continue
        
        logger.info(f"Extracted {len(all_metrics)} metrics from Prometheus")
        return all_metrics

    def _classify_severity(self, log_line: str) -> str:
        """Classify log severity based on content"""
        log_lower = log_line.lower()
        
        if any(keyword in log_lower for keyword in ['error', 'exception', 'failed', 'crash', 'fatal']):
            return 'ERROR'
        elif any(keyword in log_lower for keyword in ['warning', 'warn', 'deprecated']):
            return 'WARNING'
        elif any(keyword in log_lower for keyword in ['timeout', 'slow', 'latency']):
            return 'PERFORMANCE'
        else:
            return 'INFO'

    def _classify_metric_severity(self, metric_name: str, value: float) -> str:
        """Classify metric severity based on values and thresholds"""
        
        severity_rules = {
            'high_cpu': {'CRITICAL': 95, 'WARNING': 80},
            'high_memory': {'CRITICAL': 95, 'WARNING': 80},
            'pod_restarts': {'CRITICAL': 10, 'WARNING': 3},
            'jenkins_queue': {'CRITICAL': 20, 'WARNING': 10},
            'disk_usage': {'CRITICAL': 10, 'WARNING': 20},  # Inverted: lower is worse
            'failed_jobs': {'CRITICAL': 0.5, 'WARNING': 0.2}
        }
        
        rules = severity_rules.get(metric_name, {'CRITICAL': 100, 'WARNING': 50})
        
        if metric_name == 'disk_usage':  # Special case: lower is worse
            if value <= rules['CRITICAL']:
                return 'CRITICAL'
            elif value <= rules['WARNING']:
                return 'WARNING'
        else:  # Normal case: higher is worse
            if value >= rules['CRITICAL']:
                return 'CRITICAL'
            elif value >= rules['WARNING']:
                return 'WARNING'
                
        return 'INFO'

    async def analyze_with_openai(self, logs: List[Dict], metrics: List[Dict]) -> str:
        """Send data to Azure OpenAI for intelligent analysis"""
        
        # Prepare data summary for AI analysis
        analysis_data = {
            'timestamp': datetime.now().isoformat(),
            'summary': {
                'total_logs': len(logs),
                'error_logs': len([l for l in logs if l['severity'] == 'ERROR']),
                'warning_logs': len([l for l in logs if l['severity'] == 'WARNING']),
                'total_metrics': len(metrics),
                'critical_metrics': len([m for m in metrics if m['severity'] == 'CRITICAL']),
                'warning_metrics': len([m for m in metrics if m['severity'] == 'WARNING'])
            },
            'top_errors': logs[:10],  # Top 10 most recent errors
            'critical_metrics': [m for m in metrics if m['severity'] in ['CRITICAL', 'WARNING']]
        }
        
        # Create AI prompt for analysis
        prompt = self._create_analysis_prompt(analysis_data)
        
        try:
            response = self.openai_client.chat.completions.create(
                model=self.deployment_name,
                messages=[
                    {
                        "role": "system",
                        "content": """You are an expert Site Reliability Engineer (SRE) and Kubernetes specialist. 
                        Analyze observability data from an AKS cluster running Jenkins with spot workers. 
                        Provide actionable troubleshooting insights, root cause analysis, and preventive measures.
                        Focus on Jenkins performance, spot worker reliability, and overall cluster health."""
                    },
                    {
                        "role": "user", 
                        "content": prompt
                    }
                ],
                temperature=0.3,
                max_tokens=2000
            )
            
            return response.choices[0].message.content
            
        except Exception as e:
            logger.error(f"Error calling Azure OpenAI: {e}")
            return f"Error generating AI insights: {e}"

    def _create_analysis_prompt(self, data: Dict) -> str:
        """Create a detailed prompt for AI analysis"""
        
        prompt = f"""
OBSERVABILITY ANALYSIS REQUEST
=============================

## CLUSTER OVERVIEW
- Analysis Time: {data['timestamp']}
- Time Range: Last {self.analysis_hours} hour(s)
- Total Log Entries: {data['summary']['total_logs']}
- Error Logs: {data['summary']['error_logs']}
- Warning Logs: {data['summary']['warning_logs']}
- Critical Metrics: {data['summary']['critical_metrics']}

## TOP ERROR PATTERNS
"""
        
        for i, log in enumerate(data['top_errors'], 1):
            prompt += f"""
{i}. [{log['severity']}] {log['namespace']}/{log['pod']}
   Time: {log['timestamp']}
   Log: {log['log_line'][:200]}...
"""
        
        prompt += "\n## CRITICAL METRICS\n"
        
        for metric in data['critical_metrics']:
            prompt += f"""
- {metric['metric_name']}: {metric['value']:.2f} ({metric['severity']})
  Query: {metric['query']}
  Labels: {metric['labels']}
"""
        
        prompt += """

## ANALYSIS REQUEST

Please provide:

1. **IMMEDIATE ISSUES**: Critical problems requiring immediate attention
2. **ROOT CAUSE ANALYSIS**: Likely causes for the identified patterns
3. **TROUBLESHOOTING STEPS**: Step-by-step remediation actions
4. **PREVENTIVE MEASURES**: Long-term improvements to prevent recurrence
5. **MONITORING RECOMMENDATIONS**: Additional monitoring or alerting needed
6. **SPOT WORKER SPECIFIC**: Issues related to spot instances and cost optimization

Focus on AKS Jenkins spot workers environment with Loki/Prometheus/Grafana observability stack.
Provide kubectl commands, configuration fixes, and operational recommendations.
"""
        
        return prompt

    async def generate_insights_report(self, ai_analysis: str, logs: List[Dict], metrics: List[Dict]) -> str:
        """Generate a comprehensive markdown report"""
        
        timestamp = datetime.now()
        
        report = f"""# 🤖 AI-Powered Observability Insights

**Generated:** {timestamp.strftime('%Y-%m-%d %H:%M:%S')}  
**Analysis Period:** Last {self.analysis_hours} hour(s)  
**Cluster:** AKS Jenkins Spot Workers  

---

## 📊 EXECUTIVE SUMMARY

| Metric | Count | Severity |
|--------|-------|----------|
| Total Log Entries | {len(logs)} | - |
| Error Logs | {len([l for l in logs if l['severity'] == 'ERROR'])} | 🔴 |
| Warning Logs | {len([l for l in logs if l['severity'] == 'WARNING'])} | 🟡 |
| Critical Metrics | {len([m for m in metrics if m['severity'] == 'CRITICAL'])} | 🔴 |
| Warning Metrics | {len([m for m in metrics if m['severity'] == 'WARNING'])} | 🟡 |

---

## 🧠 AI ANALYSIS & RECOMMENDATIONS

{ai_analysis}

---

## 📋 DETAILED LOG ANALYSIS

### Error Patterns by Namespace
"""
        
        # Group logs by namespace and severity
        namespace_errors = {}
        for log in logs:
            ns = log['namespace']
            severity = log['severity']
            
            if ns not in namespace_errors:
                namespace_errors[ns] = {'ERROR': 0, 'WARNING': 0, 'PERFORMANCE': 0, 'INFO': 0}
            namespace_errors[ns][severity] += 1
        
        for namespace, counts in namespace_errors.items():
            report += f"""
#### {namespace}
- Errors: {counts['ERROR']} 🔴
- Warnings: {counts['WARNING']} 🟡  
- Performance: {counts['PERFORMANCE']} 🟠
- Info: {counts['INFO']} ℹ️
"""
        
        report += "\n### Recent Critical Logs\n"
        
        critical_logs = [l for l in logs if l['severity'] == 'ERROR'][:10]
        for log in critical_logs:
            report += f"""
**{log['timestamp'].strftime('%H:%M:%S')}** - `{log['namespace']}/{log['pod']}`  
```
{log['log_line'][:300]}
```
"""
        
        report += "\n---\n\n## 📈 METRICS ANALYSIS\n"
        
        critical_metrics = [m for m in metrics if m['severity'] in ['CRITICAL', 'WARNING']]
        if critical_metrics:
            report += "\n### Critical Metrics\n\n"
            for metric in critical_metrics:
                report += f"""
**{metric['metric_name']}**: `{metric['value']:.2f}` ({metric['severity']})  
Query: `{metric['query']}`  
Labels: {metric['labels']}  
"""
        else:
            report += "\n✅ **No critical metrics detected**\n"
        
        report += f"""

---

## 🔧 QUICK ACTIONS

### Immediate Commands
```bash
# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces | grep -E "(Error|CrashLoop|Pending)"

# Check Jenkins Master
kubectl logs -n jenkins-master jenkins-master-0 --tail=50

# Check spot workers
kubectl get pods -n jenkins-workers -l nodepool=spot

# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces
```

### Monitoring Commands  
```bash
# Check Loki logs
curl "{self.loki_endpoint}/loki/api/v1/query_range?query={{kubernetes_namespace_name=\"jenkins-master\"}}&limit=10"

# Check Prometheus metrics
curl "{self.prometheus_endpoint}/api/v1/query?query=up"

# Access Grafana dashboards
open {self.grafana_endpoint}
```

---

## 🚨 ALERTING THRESHOLDS

Based on current analysis, consider setting up alerts for:

- **Error Rate**: > 10 errors/minute in jenkins-master namespace
- **Pod Restarts**: > 3 restarts/hour for any pod  
- **CPU Usage**: > 80% for more than 5 minutes
- **Memory Usage**: > 85% for more than 5 minutes
- **Spot Instance Evictions**: Any eviction events
- **Jenkins Queue**: > 10 jobs waiting for more than 10 minutes

---

## 📱 NEXT ANALYSIS

This report was generated automatically. Next analysis scheduled in {self.query_interval} minutes.

**Configure alerts and monitoring based on these recommendations for proactive issue detection.**

---

*Generated by AI-Powered Observability System | AKS Jenkins Spot Workers*
"""
        
        return report

    async def run_analysis(self) -> None:
        """Main analysis workflow"""
        logger.info("🚀 Starting AI-Powered Observability Analysis")
        
        try:
            # Extract data from observability stack
            logger.info("📊 Extracting logs from Loki...")
            logs = await self.query_loki_errors()
            
            logger.info("📈 Extracting metrics from Prometheus...")
            metrics = await self.query_prometheus_metrics()
            
            # Generate AI insights
            logger.info("🧠 Generating AI insights with Azure OpenAI...")
            ai_analysis = await self.analyze_with_openai(logs, metrics)
            
            # Generate comprehensive report
            if self.generate_markdown:
                logger.info("📝 Generating insights report...")
                report = await self.generate_insights_report(ai_analysis, logs, metrics)
                
                # Save report
                timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                report_file = f"{self.output_dir}/ai_insights_{timestamp}.md"
                
                with open(report_file, 'w', encoding='utf-8') as f:
                    f.write(report)
                
                logger.info(f"✅ Report saved to: {report_file}")
                
                # Also save as latest
                latest_file = f"{self.output_dir}/latest_insights.md"
                with open(latest_file, 'w', encoding='utf-8') as f:
                    f.write(report)
                
                logger.info(f"✅ Latest report: {latest_file}")
            
            # Save raw data for debugging
            data_file = f"{self.output_dir}/raw_data_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            with open(data_file, 'w', encoding='utf-8') as f:
                json.dump({
                    'logs': logs,
                    'metrics': metrics,
                    'ai_analysis': ai_analysis
                }, f, indent=2, default=str)
            
            logger.info("🎉 Analysis completed successfully!")
            
        except Exception as e:
            logger.error(f"❌ Analysis failed: {e}")
            raise


async def main():
    """Main entry point"""
    analyzer = ObservabilityAnalyzer()
    await analyzer.run_analysis()


if __name__ == "__main__":
    asyncio.run(main())
