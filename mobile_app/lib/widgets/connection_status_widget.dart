import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class ConnectionStatusWidget extends StatelessWidget {
  const ConnectionStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiService>(
      builder: (context, apiService, child) {
        final isDemo = ApiService.baseUrl == 'demo';
        final baseUrl = ApiService.baseUrl;

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDemo ? Colors.orange.shade50 : Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDemo ? Colors.orange.shade200 : Colors.green.shade200,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isDemo ? Icons.wifi_off : Icons.cloud_done,
                color: isDemo ? Colors.orange : Colors.green,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDemo ? 'Demo Mode' : 'Online Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDemo
                            ? Colors.orange.shade800
                            : Colors.green.shade800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      isDemo
                          ? 'App works without backend connection'
                          : 'Connected to: $baseUrl',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
