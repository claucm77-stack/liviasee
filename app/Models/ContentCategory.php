<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ContentCategory extends Model
{
    protected $fillable = [
        'name',
        'external_id',
        'slug',
        'scope',
        'description',
        'image_path',
        'image_url',
        'sort_order',
        'is_active',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'sort_order' => 'integer',
    ];

    public function contents(): HasMany
    {
        return $this->hasMany(Content::class);
    }

    public function imageUrl(): string
    {
        if ($this->image_path) {
            return route('api.content-categories.image', $this);
        }

        return (string) ($this->image_url ?? '');
    }
}
