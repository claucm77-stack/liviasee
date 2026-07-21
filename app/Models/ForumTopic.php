<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ForumTopic extends Model
{
    protected $fillable = ['author_id', 'teacher_id', 'title', 'category', 'status'];

    public function author(): BelongsTo
    {
        return $this->belongsTo(User::class, 'author_id');
    }

    public function teacher(): BelongsTo
    {
        return $this->belongsTo(User::class, 'teacher_id');
    }

    public function replies(): HasMany
    {
        return $this->hasMany(ForumReply::class)->oldest();
    }
}
