<?php

namespace Tests\Feature;

use App\Constants\Roles;
use App\Models\Content;
use App\Models\ContentCategory;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ContentWorkflowTest extends TestCase
{
    use RefreshDatabase;

    public function test_every_web_content_type_is_persisted_and_exposed_to_the_app(): void
    {
        $admin = User::factory()->create([
            'name' => 'Administradora de contenidos',
            'firebase_uid' => 'admin-content-uid',
            'role' => Roles::ADMIN_TI,
            'is_active' => true,
        ]);
        $category = ContentCategory::query()->create([
            'name' => 'Administración',
            'slug' => 'administracion',
            'is_active' => true,
        ]);

        $cases = [
            'articulo' => [
                'article_body' => 'Texto completo',
                'reading_time' => 5,
            ],
            'video' => [
                'video_url' => 'https://example.com/video',
                'video_duration' => '10:00',
                'transcript' => 'Notas del video',
            ],
            'pdf' => [
                'pdf_url' => 'https://example.com/documento.pdf',
                'pages' => 12,
                'document_instructions' => 'Descargar y leer',
            ],
            'evento' => [
                'event_starts_at' => '2026-08-01 09:00:00',
                'event_ends_at' => '2026-08-01 11:00:00',
                'event_location' => 'Auditorio principal',
                'event_modality' => 'presencial',
                'registration_url' => 'https://example.com/registro',
                'event_agenda' => 'Agenda del evento',
            ],
        ];

        foreach ($cases as $type => $specific) {
            $title = "Contenido {$type}";
            $response = $this->actingAs($admin)->post(route('admin.contents.store'), [
                'title' => $title,
                'type' => $type,
                'content_category_id' => $category->id,
                'summary' => "Resumen {$type}",
                'image_url' => "https://example.com/{$type}.jpg",
                'author_name' => 'María Autora',
                'status' => 'publicado',
                ...$specific,
            ]);

            $response->assertRedirect(route('admin.contents.index'));
            $content = Content::query()->where('title', $title)->firstOrFail();
            $payload = json_decode((string) $content->body, true);

            $this->assertSame($type, $content->type);
            $this->assertSame($category->id, $content->content_category_id);
            $this->assertSame('admin-content-uid', $content->author_id);
            $this->assertSame('María Autora', $payload['data']['author_name']);
            $this->assertNotNull($content->published_at);
        }

        $rows = collect($this->getJson('/api/contents?per_page=100')
            ->assertOk()
            ->json('data'));

        $this->assertSame('texto', $rows->firstWhere('titulo', 'Contenido articulo')['tipo']);
        $this->assertSame('video', $rows->firstWhere('titulo', 'Contenido video')['tipo']);
        $this->assertSame('pdf', $rows->firstWhere('titulo', 'Contenido pdf')['tipo']);
        $event = $rows->firstWhere('titulo', 'Contenido evento');
        $this->assertSame('evento', $event['tipo']);
        $this->assertSame('María Autora', $event['metadata']['author_name']);
        $this->assertSame('Auditorio principal', $event['metadata']['location']);
        $this->assertSame('María Autora', $event['autorNombre']);
    }

    public function test_regular_app_users_only_receive_published_contents(): void
    {
        Content::query()->create([
            'title' => 'Contenido publicado',
            'slug' => 'contenido-publicado',
            'type' => 'articulo',
            'body' => json_encode(['data' => ['body' => 'Artículo completo']]),
            'status' => 'publicado',
            'published_at' => now(),
        ]);
        Content::query()->create([
            'title' => 'PDF sin enlace',
            'slug' => 'pdf-sin-enlace',
            'type' => 'pdf',
            'body' => json_encode(['data' => ['pdf_url' => '']]),
            'status' => 'publicado',
            'published_at' => now(),
        ]);
        Content::query()->create([
            'title' => 'Borrador privado',
            'slug' => 'borrador-privado',
            'type' => 'articulo',
            'status' => 'borrador',
        ]);

        $user = User::factory()->create([
            'role' => Roles::MICROEMPRESARIO,
            'is_active' => true,
        ]);
        Sanctum::actingAs($user);

        $this->getJson('/api/mobile/contents')
            ->assertOk()
            ->assertJsonFragment(['titulo' => 'Contenido publicado'])
            ->assertJsonMissing(['titulo' => 'PDF sin enlace'])
            ->assertJsonMissing(['titulo' => 'Borrador privado']);
    }

    public function test_mobile_rejects_publishing_content_without_a_destination(): void
    {
        $teacher = User::factory()->create([
            'role' => Roles::DOCENTE,
            'is_active' => true,
        ]);
        Sanctum::actingAs($teacher);

        $this->postJson('/api/mobile/contents', [
            'titulo' => 'Video sin enlace',
            'tipo' => 'video',
            'estado' => 'activo',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('url');
    }
}
