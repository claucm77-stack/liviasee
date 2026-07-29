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

    public function hasUsableDestination(): bool
    {
        $payload = json_decode((string) $this->body, true);
        if (! is_array($payload)) {
            return trim((string) $this->body) !== '';
        }

        $data = is_array($payload['data'] ?? null) ? $payload['data'] : [];

        return match ($this->type) {
            'video' => $this->isHttpUrl($data['video_url'] ?? null),
            'pdf' => $this->isHttpUrl($data['pdf_url'] ?? null),
            'evento' => filled($data['starts_at'] ?? null)
                || filled($data['agenda'] ?? null)
                || filled($data['location'] ?? null)
                || $this->isHttpUrl($data['registration_url'] ?? null),
            default => filled($data['body'] ?? null),
        };
    }

    private function isHttpUrl(mixed $value): bool
    {
        $url = filter_var(trim((string) $value), FILTER_VALIDATE_URL);
        if ($url === false) {
            return false;
        }

        return in_array(parse_url($url, PHP_URL_SCHEME), ['http', 'https'], true);
    }
}
