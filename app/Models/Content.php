<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Content extends Model
{
    protected $fillable = [
        'title',
        'external_id',
        'slug',
        'type',
        'content_category_id',
        'author_id',
        'summary',
        'body',
        'status',
        'featured',
        'favorites',
        'views',
        'published_at',
    ];

    protected $casts = [
        'published_at' => 'datetime',
        'featured' => 'boolean',
        'favorites' => 'array',
        'views' => 'array',
    ];

    public function contentCategory(): BelongsTo
    {
        return $this->belongsTo(ContentCategory::class);
    }
}
