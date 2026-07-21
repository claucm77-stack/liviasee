<?php

namespace App\Http\Controllers\Api;

use App\Constants\Roles;
use App\Http\Controllers\Controller;
use App\Models\TeacherChatMessage;
use App\Models\TeacherConversation;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TeacherChatController extends Controller
{
    public function index(Request $request, string $teacherKey): JsonResponse
    {
        $request->validate([
            'teacher_name' => ['nullable', 'string', 'max:255'],
            'teacher_area' => ['nullable', 'string', 'max:255'],
        ]);
        $conversation = $this->conversation($request, $teacherKey);

        return response()->json([
            'data' => $conversation->messages()->oldest('sent_at')->get()->map($this->messageData(...)),
        ]);
    }

    public function store(Request $request, string $teacherKey): JsonResponse
    {
        $data = $request->validate([
            'teacher_name' => ['nullable', 'string', 'max:255'],
            'teacher_area' => ['nullable', 'string', 'max:255'],
            'text' => ['required', 'string', 'max:4000'],
        ]);
        $conversation = $this->conversation($request, $teacherKey);
        $user = $request->user();
        $message = $conversation->messages()->create([
            'sender_id' => $user->id,
            'sender_name' => $user->name,
            'text' => trim($data['text']),
            'is_teacher' => in_array(Roles::normalize($user->role), [Roles::DOCENTE, Roles::DOCENTE_ADMIN], true),
            'sent_at' => now(),
        ]);
        $conversation->touch();

        return response()->json(['data' => $this->messageData($message)], 201);
    }

    private function conversation(Request $request, string $teacherKey): TeacherConversation
    {
        abort_if(trim($teacherKey) === '', 422, 'El docente es obligatorio.');
        $teacherRoles = [
            Roles::DOCENTE,
            Roles::DOCENTE_ADMIN,
            Roles::LEGACY_EDUCADOR,
            Roles::LEGACY_COORD,
            Roles::LEGACY_COORDINADOR,
        ];
        $teacher = User::query()
            ->whereIn('role', $teacherRoles)
            ->where('is_active', true)
            ->where(function ($query) use ($teacherKey) {
                $query->where('firebase_uid', $teacherKey);
                if (ctype_digit($teacherKey)) {
                    $query->orWhere('id', (int) $teacherKey);
                }
            })
            ->firstOrFail();

        return TeacherConversation::query()->updateOrCreate(
            ['user_id' => $request->user()->id, 'teacher_key' => $teacherKey],
            [
                'teacher_name' => $teacher->name,
                'teacher_area' => Roles::getDisplayName($teacher->role),
            ],
        );
    }

    private function messageData(TeacherChatMessage $message): array
    {
        return [
            'id' => (string) $message->id,
            'senderId' => (string) ($message->sender?->firebase_uid ?: $message->sender_id),
            'senderName' => $message->sender_name,
            'text' => $message->text,
            'sentAt' => $message->sent_at?->toIso8601String(),
            'isTeacher' => $message->is_teacher,
        ];
    }
}
