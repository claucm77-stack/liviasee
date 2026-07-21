<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Microbusiness extends Model
{
    protected $fillable = [
        'name',
        'external_id',
        'description',
        'category',
        'address',
        'latitude',
        'longitude',
        'maps_url',
        'image_url',
        'image_path',
        'owner_id',
        'contact',
        'schedule',
        'status',
        'created_on_app_at',
        'favorites',
        'average_rating',
        'ratings_count',
        'custom_fields',
    ];

    public function imageUrl(): string
    {
        if ($this->image_path) {
            return route('api.microbusiness-image', $this);
        }

        return (string) ($this->image_url ?? '');
    }

    protected $casts = [
        'latitude' => 'float',
        'longitude' => 'float',
        'created_on_app_at' => 'datetime',
        'favorites' => 'array',
        'average_rating' => 'float',
        'ratings_count' => 'integer',
        'custom_fields' => 'array',
    ];

    public function isActive(): bool
    {
        return $this->status === 'activo';
    }
}
