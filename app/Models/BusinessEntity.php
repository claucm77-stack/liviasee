<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class BusinessEntity extends Model
{
    protected $fillable = [
        'name',
        'external_id',
        'image_path',
        'image_url',
        'main_url',
        'links',
        'documents',
        'is_active',
    ];

    protected $casts = [
        'links' => 'array',
        'documents' => 'array',
        'is_active' => 'boolean',
    ];

    public function imageUrl(): string
    {
        return $this->image_path
            ? route('api.business-entities.image', $this)
            : (string) ($this->image_url ?? '');
    }

    public function firestoreResources(): array
    {
        $links = collect($this->links ?? [])
            ->filter(fn (array $item) => filled($item['name'] ?? null) && filled($item['url'] ?? null))
            ->map(fn (array $item) => [
                'name' => (string) $item['name'],
                'url' => (string) $item['url'],
                'type' => 'link',
            ]);

        $documents = collect($this->documents ?? [])
            ->filter(fn (array $item) => filled($item['name'] ?? null) && filled($item['url'] ?? null))
            ->map(fn (array $item) => [
                'name' => (string) $item['name'],
                'url' => (string) $item['url'],
                'type' => 'pdf',
            ]);

        return $links->merge($documents)->values()->all();
    }
}
