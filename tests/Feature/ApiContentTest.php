<?php

namespace Tests\Feature;

use App\Models\Content;
use App\Models\ContentCategory;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ApiContentTest extends TestCase
{
    use RefreshDatabase;

    public function test_published_article_includes_its_full_text_for_mobile_clients(): void
    {
        Content::create([
            'title' => 'Guía de ventas',
            'slug' => 'guia-de-ventas',
            'type' => 'articulo',
            'summary' => 'Resumen',
            'body' => json_encode([
                'type' => 'articulo',
                'image_url' => 'https://example.com/guia-ventas.jpg',
                'data' => ['body' => 'Contenido completo del artículo.'],
            ]),
            'status' => 'publicado',
            'published_at' => now(),
        ]);

        $this->getJson('/api/contents')
            ->assertOk()
            ->assertJsonPath('data.0.titulo', 'Guía de ventas')
            ->assertJsonPath('data.0.tipo', 'texto')
            ->assertJsonPath('data.0.url', '')
            ->assertJsonPath('data.0.imagen', 'https://example.com/guia-ventas.jpg')
            ->assertJsonPath('data.0.contenido', 'Contenido completo del artículo.')
            ->assertJsonPath('data.0.metadata.body', 'Contenido completo del artículo.');
    }

    public function test_content_contract_preserves_event_type_and_named_author(): void
    {
        Content::create([
            'title' => 'Taller de ventas',
            'slug' => 'taller-de-ventas',
            'type' => 'evento',
            'body' => json_encode([
                'type' => 'evento',
                'category' => 'Cronograma Actividades',
                'data' => [
                    'agenda' => 'Agenda del taller.',
                    'author_name' => 'María Pérez',
                ],
            ]),
            'status' => 'publicado',
            'published_at' => now(),
        ]);

        $this->getJson('/api/contents')
            ->assertOk()
            ->assertJsonPath('data.0.tipo', 'evento')
            ->assertJsonPath('data.0.categoria', 'Cronograma Actividades')
            ->assertJsonPath('data.0.autorNombre', 'María Pérez')
            ->assertJsonPath('data.0.contenido', 'Agenda del taller.');
    }

    public function test_mobile_receives_laravel_categories_and_their_associated_contents(): void
    {
        $category = ContentCategory::create([
            'name' => 'Publicidad y Mercadeo',
            'slug' => 'publicidad-y-mercadeo',
            'description' => 'Estrategias para promocionar negocios.',
            'sort_order' => 1,
            'is_active' => true,
        ]);

        Content::create([
            'title' => 'Campaña digital',
            'slug' => 'campana-digital',
            'type' => 'articulo',
            'content_category_id' => $category->id,
            'body' => json_encode(['data' => ['body' => 'Guía de campaña.']]),
            'status' => 'publicado',
            'published_at' => now(),
        ]);

        $this->getJson('/api/content-categories')
            ->assertOk()
            ->assertJsonPath('data.0.nombre', 'Publicidad y Mercadeo');

        $this->getJson('/api/contents')
            ->assertOk()
            ->assertJsonPath('data.0.categoria', 'Publicidad y Mercadeo');
    }

    public function test_category_image_is_served_through_the_api(): void
    {
        Storage::fake('public');
        Storage::disk('public')->put('content-categories/category.jpg', 'category-image');

        $category = ContentCategory::create([
            'name' => 'Administración',
            'slug' => 'administracion',
            'image_path' => 'content-categories/category.jpg',
            'is_active' => true,
        ]);

        $this->getJson('/api/content-categories')
            ->assertOk()
            ->assertJsonPath('data.0.imageUrl', route('api.content-categories.image', $category));

        $this->get(route('api.content-categories.image', $category))
            ->assertOk()
            ->assertStreamedContent('category-image');
    }
}
