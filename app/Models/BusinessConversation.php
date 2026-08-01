<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class BusinessConversation extends Model
{
    protected $fillable = [
        'microbusiness_id',
        'customer_id',
        'owner_user_id',
        'customer_last_read_message_id',
        'owner_last_read_message_id',
    ];

    public function business(): BelongsTo
    {
        return $this->belongsTo(Microbusiness::class, 'microbusiness_id');
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'customer_id');
    }

    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'owner_user_id');
    }

    public function messages(): HasMany
    {
        return $this->hasMany(BusinessChatMessage::class, 'conversation_id');
    }
}
