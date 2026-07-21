<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class TeacherConversation extends Model
{
    protected $fillable = ['user_id', 'teacher_key', 'teacher_name', 'teacher_area'];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function messages(): HasMany
    {
        return $this->hasMany(TeacherChatMessage::class, 'conversation_id');
    }
}
