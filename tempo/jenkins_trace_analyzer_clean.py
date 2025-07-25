#!/usr/bin/env python3
"""
Jenkins Master-Pod Trace Analyzer
================================

Analizador inteligente que correlaciona trazas de Tempo con logs de Loki
para identificar cuándo falla Jenkins Master y qué estaba pasando en los pods.

Este script:
1. Consulta trazas de Jenkins Master desde Tempo
2. Identifica trazas con errores o alta latencia
3. Correlaciona con logs de pods en el momento del fallo
4. Genera un reporte con análisis AI-powered

Autor: Platform Engineer
Fecha: 2025-07-25
"""

import requests
import json
import time
import datetime
from typing import Dict, List, Optional, Any
from dataclasses import dataclass
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class TraceSpan:
    """Representa un span de traza de Tempo"""
    trace_id: str
    span_id: str
    service_name: str
    operation_name: str
    start_time: int
    duration: int
    status_code: str
    tags: Dict[str, Any]

@dataclass
class CorrelatedEvent:
    """Evento correlacionado entre trazas y logs"""
    trace: TraceSpan
    logs: List[Dict[str, Any]]
    analysis: str
    severity: str

class TempoClient:
    """Cliente para consultar trazas de Tempo"""
    
    def __init__(self, tempo_url: str = "http://localhost:3200"):
        self.tempo_url = tempo_url.rstrip('/')
        
    def search_traces(self, 
                     service_name: str = "jenkins-master",
                     start_time: Optional[int] = None,
                     end_time: Optional[int] = None,
                     limit: int = 100) -> List[TraceSpan]:
        """Busca trazas en Tempo"""
        
        if not start_time:
            start_time = int((datetime.datetime.now() - datetime.timedelta(hours=1)).timestamp() * 1000000000)
        if not end_time:
            end_time = int(datetime.datetime.now().timestamp() * 1000000000)
            
        # Tempo API search endpoint
        search_url = f"{self.tempo_url}/api/search"
        params = {
            'tags': f'service.name={service_name}',
            'start': start_time,
            'end': end_time,
            'limit': limit
        }
        
        try:
            response = requests.get(search_url, params=params, timeout=30)
            response.raise_for_status()
            
            traces_data = response.json()
            traces = []
            
            for trace_data in traces_data.get('traces', []):
                trace_id = trace_data.get('traceID')
                if trace_id:
                    # Obtener detalles completos de la traza
                    trace_details = self.get_trace_details(trace_id)
                    if trace_details:
                        traces.extend(trace_details)
                        
            return traces
            
        except requests.RequestException as e:
            logger.error(f"Error consultando Tempo: {e}")
            return []
    
    def get_trace_details(self, trace_id: str) -> List[TraceSpan]:
        """Obtiene detalles completos de una traza"""
        
        trace_url = f"{self.tempo_url}/api/traces/{trace_id}"
        
        try:
            response = requests.get(trace_url, timeout=30)
            response.raise_for_status()
            
            trace_data = response.json()
            spans = []
            
            for batch in trace_data.get('batches', []):
                for span_data in batch.get('spans', []):
                    span = TraceSpan(
                        trace_id=trace_id,
                        span_id=span_data.get('spanID', ''),
                        service_name=self._extract_service_name(span_data),
                        operation_name=span_data.get('operationName', ''),
                        start_time=span_data.get('startTimeUnixNano', 0),
                        duration=span_data.get('durationNanos', 0),
                        status_code=self._extract_status_code(span_data),
                        tags=self._extract_tags(span_data)
                    )
                    spans.append(span)
                    
            return spans
            
        except requests.RequestException as e:
            logger.error(f"Error obteniendo detalles de traza {trace_id}: {e}")
            return []
    
    def _extract_service_name(self, span_data: Dict) -> str:
        """Extrae el nombre del servicio de un span"""
        for tag in span_data.get('tags', []):
            if tag.get('key') == 'service.name':
                return tag.get('vStr', '')
        return 'unknown'
    
    def _extract_status_code(self, span_data: Dict) -> str:
        """Extrae el código de estado de un span"""
        for tag in span_data.get('tags', []):
            if tag.get('key') == 'otel.status_code':
                return tag.get('vStr', '')
        return 'unset'
    
    def _extract_tags(self, span_data: Dict) -> Dict[str, Any]:
        """Extrae todos los tags de un span"""
        tags = {}
        for tag in span_data.get('tags', []):
            key = tag.get('key', '')
            if 'vStr' in tag:
                tags[key] = tag['vStr']
            elif 'vInt64' in tag:
                tags[key] = tag['vInt64']
            elif 'vBool' in tag:
                tags[key] = tag['vBool']
        return tags

class LokiClient:
    """Cliente para consultar logs de Loki"""
    
    def __init__(self, loki_url: str = "http://localhost:3100"):
        self.loki_url = loki_url.rstrip('/')
        
    def query_logs_around_time(self, 
                              timestamp: int,
                              window_minutes: int = 5,
                              namespace: str = "jenkins") -> List[Dict[str, Any]]:
        """Consulta logs alrededor de un timestamp específico"""
        
        # Convertir nanosegundos a segundos
        timestamp_seconds = timestamp // 1000000000
        start_time = timestamp_seconds - (window_minutes * 60)
        end_time = timestamp_seconds + (window_minutes * 60)
        
        query_url = f"{self.loki_url}/loki/api/v1/query_range"
        
        # Query LogQL para buscar logs relevantes
        logql_query = f'{{namespace="{namespace}"}} | json | line_format "{{{{.timestamp}}}} [{{{{.level}}}}] {{{{.service}}}}: {{{{.message}}}}"'
        
        params = {
            'query': logql_query,
            'start': start_time,
            'end': end_time,
            'limit': 1000
        }
        
        try:
            response = requests.get(query_url, params=params, timeout=30)
            response.raise_for_status()
            
            logs_data = response.json()
            logs = []
            
            for stream in logs_data.get('data', {}).get('result', []):
                stream_labels = stream.get('stream', {})
                for values in stream.get('values', []):
                    log_entry = {
                        'timestamp': values[0],
                        'line': values[1],
                        'labels': stream_labels
                    }
                    logs.append(log_entry)
                    
            return sorted(logs, key=lambda x: x['timestamp'])
            
        except requests.RequestException as e:
            logger.error(f"Error consultando Loki: {e}")
            return []

class JenkinsTraceAnalyzer:
    """Analizador principal que correlaciona trazas con logs"""
    
    def __init__(self, tempo_url: str = "http://localhost:3200", 
                 loki_url: str = "http://localhost:3100"):
        self.tempo = TempoClient(tempo_url)
        self.loki = LokiClient(loki_url)
        
    def analyze_jenkins_failures(self, hours_back: int = 1) -> List[CorrelatedEvent]:
        """Analiza fallos de Jenkins Master correlacionando trazas y logs"""
        
        logger.info(f"🔍 Analizando fallos de Jenkins en las últimas {hours_back} horas...")
        
        # Buscar trazas de Jenkins Master
        end_time = int(datetime.datetime.now().timestamp() * 1000000000)
        start_time = int((datetime.datetime.now() - datetime.timedelta(hours=hours_back)).timestamp() * 1000000000)
        
        traces = self.tempo.search_traces(
            service_name="jenkins-master",
            start_time=start_time,
            end_time=end_time
        )
        
        logger.info(f"📊 Encontradas {len(traces)} trazas de Jenkins Master")
        
        # Identificar trazas problemáticas
        problematic_traces = self._identify_problematic_traces(traces)
        logger.info(f"⚠️ Identificadas {len(problematic_traces)} trazas problemáticas")
        
        # Correlacionar con logs
        correlated_events = []
        for trace in problematic_traces:
            logs = self.loki.query_logs_around_time(
                timestamp=trace.start_time,
                window_minutes=5,
                namespace="jenkins"
            )
            
            analysis = self._analyze_correlation(trace, logs)
            severity = self._calculate_severity(trace, logs)
            
            event = CorrelatedEvent(
                trace=trace,
                logs=logs,
                analysis=analysis,
                severity=severity
            )
            correlated_events.append(event)
            
        return correlated_events
    
    def _identify_problematic_traces(self, traces: List[TraceSpan]) -> List[TraceSpan]:
        """Identifica trazas problemáticas (errores, alta latencia)"""
        
        problematic = []
        
        for trace in traces:
            # Criterios para considerar una traza problemática:
            # 1. Status code de error
            # 2. Duración > 5 segundos (5000000000 nanosegundos)
            # 3. Tags que indican problemas
            
            is_error = trace.status_code in ['ERROR', 'FAILED', '2']
            is_slow = trace.duration > 5000000000  # 5 segundos
            has_error_tags = any(
                'error' in str(value).lower() or 'fail' in str(value).lower()
                for value in trace.tags.values()
            )
            
            if is_error or is_slow or has_error_tags:
                problematic.append(trace)
                
        return problematic
    
    def _analyze_correlation(self, trace: TraceSpan, logs: List[Dict[str, Any]]) -> str:
        """Analiza la correlación entre una traza y los logs"""
        
        # Análisis básico de patrones en logs
        error_logs = [
            log for log in logs 
            if any(keyword in log['line'].lower() 
                  for keyword in ['error', 'exception', 'failed', 'timeout'])
        ]
        
        warning_logs = [
            log for log in logs 
            if any(keyword in log['line'].lower() 
                  for keyword in ['warning', 'warn', 'retry'])
        ]
        
        analysis_parts = []
        
        # Información de la traza
        duration_ms = trace.duration / 1000000  # Convertir a milisegundos
        analysis_parts.append(f"Traza {trace.operation_name} duró {duration_ms:.2f}ms")
        
        if trace.status_code in ['ERROR', 'FAILED', '2']:
            analysis_parts.append(f"Estado: {trace.status_code}")
        
        # Análisis de logs correlacionados
        if error_logs:
            analysis_parts.append(f"🔴 {len(error_logs)} logs de error encontrados")
            # Mostrar el primer error
            if error_logs:
                first_error = error_logs[0]['line'][:200]
                analysis_parts.append(f"Primer error: {first_error}")
        
        if warning_logs:
            analysis_parts.append(f"🟡 {len(warning_logs)} warnings encontrados")
        
        # Análisis de patrones temporales
        if len(logs) > 10:
            analysis_parts.append(f"📊 Alta actividad: {len(logs)} logs en ventana de 10min")
        
        return " | ".join(analysis_parts) if analysis_parts else "Sin patrones significativos detectados"
    
    def _calculate_severity(self, trace: TraceSpan, logs: List[Dict[str, Any]]) -> str:
        """Calcula la severidad de un evento"""
        
        score = 0
        
        # Puntuación por estado de traza
        if trace.status_code in ['ERROR', 'FAILED', '2']:
            score += 3
        
        # Puntuación por duración
        duration_seconds = trace.duration / 1000000000
        if duration_seconds > 10:
            score += 3
        elif duration_seconds > 5:
            score += 2
        elif duration_seconds > 2:
            score += 1
        
        # Puntuación por logs de error
        error_count = sum(
            1 for log in logs 
            if any(keyword in log['line'].lower() 
                  for keyword in ['error', 'exception', 'failed'])
        )
        score += min(error_count, 3)
        
        # Clasificación final
        if score >= 6:
            return "CRITICAL"
        elif score >= 4:
            return "HIGH"
        elif score >= 2:
            return "MEDIUM"
        else:
            return "LOW"
    
    def generate_report(self, events: List[CorrelatedEvent]) -> str:
        """Genera un reporte detallado de los eventos correlacionados"""
        
        report_lines = []
        report_lines.append("=" * 80)
        report_lines.append("REPORTE DE ANÁLISIS: JENKINS MASTER-POD CORRELATION")
        report_lines.append("=" * 80)
        report_lines.append(f"Fecha: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report_lines.append(f"Eventos analizados: {len(events)}")
        report_lines.append("")
        
        # Resumen por severidad
        severity_count = {}
        for event in events:
            severity_count[event.severity] = severity_count.get(event.severity, 0) + 1
        
        report_lines.append("RESUMEN POR SEVERIDAD:")
        for severity in ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW']:
            count = severity_count.get(severity, 0)
            if count > 0:
                report_lines.append(f"  {severity}: {count} eventos")
        report_lines.append("")
        
        # Detalle de eventos críticos y altos
        critical_events = [e for e in events if e.severity in ['CRITICAL', 'HIGH']]
        if critical_events:
            report_lines.append("EVENTOS CRÍTICOS Y DE ALTA PRIORIDAD:")
            report_lines.append("-" * 50)
            
            for i, event in enumerate(critical_events, 1):
                timestamp = datetime.datetime.fromtimestamp(
                    event.trace.start_time / 1000000000
                ).strftime('%Y-%m-%d %H:%M:%S')
                
                report_lines.append(f"{i}. EVENTO {event.severity}")
                report_lines.append(f"   Timestamp: {timestamp}")
                report_lines.append(f"   Operación: {event.trace.operation_name}")
                report_lines.append(f"   Servicio: {event.trace.service_name}")
                report_lines.append(f"   Trace ID: {event.trace.trace_id}")
                report_lines.append(f"   Análisis: {event.analysis}")
                report_lines.append(f"   Logs correlacionados: {len(event.logs)}")
                
                # Mostrar algunos logs relevantes
                error_logs = [
                    log for log in event.logs[:5] 
                    if any(keyword in log['line'].lower() 
                          for keyword in ['error', 'exception', 'failed'])
                ]
                if error_logs:
                    report_lines.append("   Logs de error:")
                    for log in error_logs[:3]:
                        line = log['line'][:100] + "..." if len(log['line']) > 100 else log['line']
                        report_lines.append(f"     - {line}")
                
                report_lines.append("")
        
        # Recomendaciones
        report_lines.append("RECOMENDACIONES:")
        report_lines.append("-" * 20)
        
        if any(e.severity == 'CRITICAL' for e in events):
            report_lines.append("🔴 ACCIÓN INMEDIATA REQUERIDA:")
            report_lines.append("   - Revisar logs de Jenkins Master inmediatamente")
            report_lines.append("   - Verificar conectividad con nodos worker")
            report_lines.append("   - Evaluar escalado de recursos")
        
        if len([e for e in events if e.severity in ['HIGH', 'CRITICAL']]) > 5:
            report_lines.append("🟡 PATRÓN DE FALLOS DETECTADO:")
            report_lines.append("   - Considerar análisis de tendencias")
            report_lines.append("   - Revisar configuración de Jenkins")
            report_lines.append("   - Evaluar capacidad del cluster")
        
        report_lines.append("")
        report_lines.append("Para más detalles, consultar Grafana Dashboard:")
        report_lines.append("http://localhost:3000/d/jenkins-tempo-tracing/jenkins-master-pod-distributed-tracing")
        
        return "\n".join(report_lines)

def main():
    """Función principal"""
    
    print("🚀 Iniciando análisis de correlación Jenkins Master-Pod...")
    
    # Configuración (puedes modificar estas URLs según tu setup)
    tempo_url = "http://localhost:3200"  # Puerto de Tempo
    loki_url = "http://localhost:3100"   # Puerto de Loki
    
    # Inicializar analizador
    analyzer = JenkinsTraceAnalyzer(tempo_url, loki_url)
    
    # Realizar análisis
    events = analyzer.analyze_jenkins_failures(hours_back=2)
    
    # Generar reporte
    report = analyzer.generate_report(events)
    
    # Mostrar reporte
    print("\n" + report)
    
    # Guardar reporte en archivo
    timestamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
    report_file = f"jenkins_correlation_report_{timestamp}.txt"
    
    with open(report_file, 'w') as f:
        f.write(report)
    
    print(f"\n📄 Reporte guardado en: {report_file}")
    
    return events

if __name__ == "__main__":
    try:
        events = main()
        print(f"\n✅ Análisis completado. {len(events)} eventos procesados.")
    except Exception as e:
        logger.error(f"❌ Error durante el análisis: {e}")
        raise
