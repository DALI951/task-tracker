import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:task_tracker/models/task.dart';

class TaskCard extends StatelessWidget {
  final AppTask task;
  final VoidCallback? onTap;

  const TaskCard({super.key, required this.task, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color:
                                  task.isCompleted ? Colors.grey : null,
                            ),
                          ),
                        ),
                        _statusBadge(task),
                      ],
                    ),
                    if (task.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          task.assignedTo,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        if (task.claimedByName != null) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.person_pin,
                              size: 14, color: Colors.orange.shade400),
                          const SizedBox(width: 2),
                          Text(
                            task.claimedByName!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade600,
                            ),
                          ),
                        ],
                        if (task.customer != null) ...[
                          const Spacer(),
                          Icon(Icons.business,
                              size: 14, color: Colors.grey.shade400),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              task.customer!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (task.photoUrl != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      base64Decode(task.photoUrl!),
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 48,
                        height: 48,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, size: 24),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(AppTask task) {
    if (task.isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Done',
          style: TextStyle(
            fontSize: 11,
            color: Colors.green.shade800,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    if (task.isPendingReview) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.purple.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Review',
          style: TextStyle(
            fontSize: 11,
            color: Colors.purple.shade800,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    if (task.isDoing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Doing',
          style: TextStyle(
            fontSize: 11,
            color: Colors.blue.shade800,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Pending',
        style: TextStyle(
          fontSize: 11,
          color: Colors.orange.shade800,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
