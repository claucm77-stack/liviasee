<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TeacherChatMessage extends Model
{
    protected $fillable = [
        'conversation_id',
        'sender_id',
        'sender_name',
        'text',
        'is_teacher',
        'sent_at',
    ];

    protected function casts(): array
    {
        return [
            'is_teacher' => 'boolean',
            'sent_at' => 'datetime',
        ];
    }

    public function conversation(): BelongsTo
    {
        return $this->belongsTo(TeacherConversation::class, 'conversation_id');
    }

    public function sender(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sender_id');
    }
}
