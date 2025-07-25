#!/usr/bin/env python3
"""
Continuous AI Observability Monitor
===================================

This script runs the observability analyzer continuously, 
generating insights at regular intervals.
"""

import asyncio
import logging
import signal
import sys
from datetime import datetime
from ai_observability_analyzer import ObservabilityAnalyzer

logger = logging.getLogger(__name__)

class ContinuousMonitor:
    """Continuous monitoring service"""
    
    def __init__(self, interval_minutes: int = 5):
        self.interval_minutes = interval_minutes
        self.analyzer = ObservabilityAnalyzer()
        self.running = True
        
        # Setup signal handlers for graceful shutdown
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        logger.info(f"Received signal {signum}, shutting down gracefully...")
        self.running = False
    
    async def run(self):
        """Main monitoring loop"""
        logger.info(f"🔄 Starting continuous monitoring (interval: {self.interval_minutes} minutes)")
        
        iteration = 0
        
        while self.running:
            try:
                iteration += 1
                logger.info(f"🔍 Analysis iteration #{iteration} - {datetime.now()}")
                
                # Run analysis
                await self.analyzer.run_analysis()
                
                # Wait for next interval
                if self.running:
                    logger.info(f"⏱️  Waiting {self.interval_minutes} minutes until next analysis...")
                    await asyncio.sleep(self.interval_minutes * 60)
                    
            except KeyboardInterrupt:
                logger.info("🛑 Received interrupt signal")
                break
            except Exception as e:
                logger.error(f"❌ Error in monitoring loop: {e}")
                logger.info(f"🔄 Retrying in {self.interval_minutes} minutes...")
                
                if self.running:
                    await asyncio.sleep(self.interval_minutes * 60)
        
        logger.info("✅ Monitoring stopped")

async def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Continuous AI Observability Monitor')
    parser.add_argument(
        '--interval', 
        type=int, 
        default=5, 
        help='Analysis interval in minutes (default: 5)'
    )
    
    args = parser.parse_args()
    
    monitor = ContinuousMonitor(interval_minutes=args.interval)
    await monitor.run()

if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s'
    )
    
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n👋 Goodbye!")
        sys.exit(0)
