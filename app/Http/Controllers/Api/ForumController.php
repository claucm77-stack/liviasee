<?php

namespace App\Http\Controllers\Api;

use App\Constants\Roles;
use App\Http\Controllers\Controller;
use App\Models\ForumReply;
use App\Models\ForumTopic;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ForumController extends Controller
{
    public function index(): JsonResponse
    {
        $topics = ForumTopic::query()
            ->with(['author', 'teacher', 'replies.author'])
            ->latest()
            ->get()
            ->map($this->topicData(...));

        return response()->json(['data' => $topics]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'title' => ['required', 'string', 'max:255'],
            'category' => ['nullable', 'string', 'max:100'],
            'teacher_id' => ['required', 'string', 'max:255'],
        ]);
        $teacher = $this->activeTeacher($data['teacher_id']);
        $topic = ForumTopic::query()->create([
            'author_id' => $request->user()->id,
            'teacher_id' => $teacher->id,
            'title' => trim($data['title']),
            'category' => trim((string) ($data['category'] ?? '')) ?: 'General',
            'status' => 'pendiente',
        ]);

        return response()->json(['data' => $this->topicData($topic->load(['author', 'teacher', 'replies.author']))], 201);
    }

    public function reply(Request $request, ForumTopic $forumTopic): JsonResponse
    {
        $data = $request->validate(['text' => ['required', 'string', 'max:4000']]);
        $user = $request->user();
        $normalizedRole = Roles::normalize($user->role);
        abort_unless(
            $forumTopic->teacher_id === $user->id
                || in_array($normalizedRole, [Roles::DOCENTE_ADMIN, Roles::ADMIN_TI], true),
            403,
            'Solo el docente asociado puede responder este foro.',
        );

        $reply = $forumTopic->replies()->create([
            'author_id' => $user->id,
            'text' => trim($data['text']),
        ]);
        $forumTopic->update(['status' => 'respondido']);

        return response()->json(['data' => $this->replyData($reply->load('author'))], 201);
    }

    private function activeTeacher(string $identifier): User
    {
        $teacherRoles = [
            Roles::DOCENTE,
            Roles::DOCENTE_ADMIN,
            Roles::LEGACY_EDUCADOR,
            Roles::LEGACY_COORD,
            Roles::LEGACY_COORDINADOR,
        ];

        return User::query()
            ->whereIn('role', $teacherRoles)
            ->where('is_active', true)
            ->where(function ($query) use ($identifier) {
                $query->where('firebase_uid', $identifier);
                if (ctype_digit($identifier)) {
                    $query->orWhere('id', (int) $identifier);
                }
            })
            ->firstOrFail();
    }

    private function topicData(ForumTopic $topic): array
    {
        return [
            'id' => (string) $topic->id,
            'title' => $topic->title,
            'category' => $topic->category,
            'status' => $topic->status === 'respondido' ? 'Respondido por docente' : 'Pendiente de respuesta',
            'authorId' => (string) ($topic->author?->firebase_uid ?: $topic->author_id),
            'authorName' => $topic->author?->name ?? 'Usuario',
            'teacherId' => (string) ($topic->teacher?->firebase_uid ?: $topic->teacher_id),
            'teacherName' => $topic->teacher?->name ?? 'Docente',
            'teacherImage' => $topic->teacher?->photoUrl() ?? '',
            'createdAt' => $topic->created_at?->toIso8601String(),
            'replies' => $topic->replies->map($this->replyData(...))->values(),
        ];
    }

    private function replyData(ForumReply $reply): array
    {
        return [
            'id' => (string) $reply->id,
            'text' => $reply->text,
            'teacherId' => (string) ($reply->author?->firebase_uid ?: $reply->author_id),
            'teacherName' => $reply->author?->name ?? 'Docente',
            'createdAt' => $reply->created_at?->toIso8601String(),
        ];
    }
}
