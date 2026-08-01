<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\BusinessChatMessage;
use App\Models\BusinessConversation;
use App\Models\Microbusiness;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BusinessChatController extends Controller
{
    public function conversations(Request $request): JsonResponse
    {
        $user = $request->user();
        $conversations = BusinessConversation::query()
            ->with(['business', 'customer', 'owner', 'messages' => fn ($query) => $query->latest('sent_at')->limit(1)])
            ->where(fn ($query) => $query->where('customer_id', $user->id)->orWhere('owner_user_id', $user->id))
            ->latest('updated_at')
            ->get();

        return response()->json(['data' => $conversations->map(fn (BusinessConversation $conversation) => $this->conversationData($conversation, $user))]);
    }

    public function index(Request $request, string $businessKey): JsonResponse
    {
        $conversation = $this->conversation($request, $businessKey);
        $this->markRead($conversation, $request->user());

        return response()->json([
            'data' => $conversation->messages()->with('sender')->oldest('sent_at')->get()->map($this->messageData(...)),
        ]);
    }

    public function store(Request $request, string $businessKey): JsonResponse
    {
        $data = $request->validate([
            'customer_id' => ['nullable', 'string', 'max:255'],
            'text' => ['required', 'string', 'max:4000'],
        ]);
        $conversation = $this->conversation($request, $businessKey);
        $user = $request->user();
        $message = $conversation->messages()->create([
            'sender_id' => $user->id,
            'sender_name' => $user->name,
            'text' => trim($data['text']),
            'sent_at' => now(),
        ]);
        $this->markRead($conversation, $user);
        $conversation->touch();

        return response()->json(['data' => $this->messageData($message->load('sender'))], 201);
    }

    private function conversation(Request $request, string $businessKey): BusinessConversation
    {
        $business = $this->business($businessKey);
        $owner = $this->userByKey((string) $business->owner_id);
        abort_unless($owner, 422, 'El propietario del micronegocio no tiene una cuenta válida.');

        $user = $request->user();
        if ($user->is($owner)) {
            $customerKey = trim((string) $request->input('customer_id', $request->query('customer_id', '')));
            abort_if($customerKey === '', 422, 'Selecciona una conversación para responder.');
            $customer = $this->userByKey($customerKey);
            abort_unless($customer, 404, 'El usuario de la conversación no existe.');
        } else {
            $customer = $user;
        }

        return BusinessConversation::query()->firstOrCreate([
            'microbusiness_id' => $business->id,
            'customer_id' => $customer->id,
        ], [
            'owner_user_id' => $owner->id,
        ]);
    }

    private function markRead(BusinessConversation $conversation, User $user): void
    {
        $field = $conversation->owner_user_id === $user->id
            ? 'owner_last_read_message_id'
            : 'customer_last_read_message_id';
        $lastMessageId = $conversation->messages()->max('id');
        if ($lastMessageId) {
            $conversation->forceFill([$field => $lastMessageId])->save();
        }
    }

    private function conversationData(BusinessConversation $conversation, User $user): array
    {
        $isOwner = $conversation->owner_user_id === $user->id;
        $lastReadMessageId = $isOwner
            ? $conversation->owner_last_read_message_id
            : $conversation->customer_last_read_message_id;
        $lastMessage = $conversation->messages->first();
        $unread = $conversation->messages()
            ->where('sender_id', '!=', $user->id)
            ->when($lastReadMessageId, fn ($query) => $query->where('id', '>', $lastReadMessageId))
            ->count();

        return [
            'id' => (string) $conversation->id,
            'businessId' => (string) ($conversation->business->external_id ?: $conversation->business->id),
            'businessName' => $conversation->business->name,
            'businessImage' => $conversation->business->imageUrl(),
            'customerId' => (string) ($conversation->customer->firebase_uid ?: $conversation->customer->id),
            'customerName' => $conversation->customer->name,
            'ownerId' => (string) ($conversation->owner->firebase_uid ?: $conversation->owner->id),
            'isOwner' => $isOwner,
            'lastMessage' => $lastMessage?->text ?? '',
            'lastMessageAt' => $lastMessage?->sent_at?->toIso8601String(),
            'unreadCount' => $unread,
        ];
    }

    private function messageData(BusinessChatMessage $message): array
    {
        return [
            'id' => (string) $message->id,
            'senderId' => (string) ($message->sender?->firebase_uid ?: $message->sender_id),
            'senderName' => $message->sender_name,
            'text' => $message->text,
            'sentAt' => $message->sent_at?->toIso8601String(),
        ];
    }

    private function business(string $key): Microbusiness
    {
        return Microbusiness::query()
            ->where('external_id', $key)
            ->when(ctype_digit($key), fn ($query) => $query->orWhere('id', (int) $key))
            ->firstOrFail();
    }

    private function userByKey(string $key): ?User
    {
        return User::query()
            ->where('firebase_uid', $key)
            ->when(ctype_digit($key), fn ($query) => $query->orWhere('id', (int) $key))
            ->first();
    }
}
