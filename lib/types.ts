export type Role = string;

export type Department = string;

export type User = {
  id: string;
  name: string;
  role: Role;
  tipo_usuario?: string;
  avatar?: string;
  email?: string;
  department?: Department | string;
};

export type Category = string;

export type Priority = string;

export type Status = string;

export type Comment = {
  id: string;
  userId: string;
  text: string;
  createdAt: string;
};

export type TimelineEvent = {
  id: string;
  type: 'created' | 'assigned' | 'status_changed' | 'commented' | 'transferred' | 'completed' | 'other';
  userId: string;
  description: string;
  createdAt: string;
};

export type Task = {
  id: string;
  title: string;
  description: string;
  category: Category;
  priority: Priority;
  status: Status;
  requesterId: string;
  requesterName: string;
  department: Department | string;
  assigneeId?: string;
  createdAt: string;
  dueDate: string;
  comments: Comment[];
  timeline: TimelineEvent[];
  referenceLinks?: string[];
  notes?: string;
  updatedAt?: string;
  startedAt?: string;
  distributedAt?: string;
  completedAt?: string;
  externalConsultant?: string;
  internalConsultant?: string;
};