<?php

namespace Tests\Feature;

use App\Constants\Roles;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use App\Services\FirebaseTokenService;
use Mockery;
use Tests\TestCase;

class MobileBidirectionalSyncTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();
        $this->admin = User::factory()->create([
            'role' => Roles::ADMIN_TI,
            'is_active' => true,
            'firebase_uid' => 'firebase-admin',
        ]);
        Sanctum::actingAs($this->admin);
    }

    public function test_mobile_writes_are_persisted_and_visible_to_the_web(): void
    {
        $this->postJson('/api/mobile/categories', [
            'id' => 'mobile-category-1',
            'nombre' => 'Categoría desde app',
            'scope' => 'contenidos',
            'descripcion' => 'Visible en ambos lados',
            'imageUrl' => 'https://example.com/category.jpg',
            'orden' => 1,
            'isActive' => true,
        ])->assertCreated()->assertJsonPath('data.id', 'mobile-category-1');

        $this->postJson('/api/mobile/contents', [
            'id' => 'mobile-content-1',
            'titulo' => 'Contenido desde app',
            'descripcion' => 'Descripción compartida',
            'tipo' => 'texto',
            'contenido' => 'Texto completo',
            'imagen' => 'https://example.com/content.jpg',
            'categoria' => 'Categoría desde app',
            'autorId' => 'firebase-admin',
            'estado' => 'activo',
        ])->assertCreated()->assertJsonPath('data.id', 'mobile-content-1');

        $this->postJson('/api/mobile/microbusinesses', [
            'id' => 'mobile-business-1',
            'nombre' => 'Negocio desde app',
            'descripcion' => 'Negocio compartido',
            'categoria' => 'Servicios',
            'direccion' => 'Bogotá',
            'latitud' => 4.711,
            'longitud' => -74.0721,
            'propietarioId' => 'firebase-admin',
            'estado' => 'activo',
        ])->assertCreated()->assertJsonPath('data.id', 'mobile-business-1');

        $this->postJson('/api/mobile/entities', [
            'id' => 'mobile-entity-1',
            'name' => 'Entidad desde app',
            'imageUrl' => 'https://example.com/entity.jpg',
            'mainUrl' => 'https://example.com',
            'resources' => [['name' => 'Portal', 'url' => 'https://example.com', 'type' => 'link']],
        ])->assertCreated()->assertJsonPath('data.id', 'mobile-entity-1');

        $this->assertDatabaseHas('content_categories', ['external_id' => 'mobile-category-1']);
        $this->assertDatabaseHas('contents', ['external_id' => 'mobile-content-1']);
        $this->assertDatabaseHas('microbusinesses', ['external_id' => 'mobile-business-1']);
        $this->assertDatabaseHas('business_entities', ['external_id' => 'mobile-entity-1']);

        $this->actingAs($this->admin)->get('/admin/content-categories')->assertOk()->assertSee('Categoría desde app');
        $this->actingAs($this->admin)->get('/admin/contents')->assertOk()->assertSee('Contenido desde app');
        $this->actingAs($this->admin)->get('/admin/microbusinesses')->assertOk()->assertSee('Negocio desde app');
        $this->actingAs($this->admin)->get('/admin/entities')->assertOk()->assertSee('Entidad desde app');
    }

    public function test_web_records_are_returned_to_the_mobile_contract(): void
    {
        $category = \App\Models\ContentCategory::create([
            'name' => 'Categoría desde web', 'slug' => 'categoria-desde-web', 'scope' => 'contenidos', 'is_active' => true,
        ]);
        \App\Models\Content::create([
            'title' => 'Contenido desde web', 'slug' => 'contenido-desde-web', 'type' => 'articulo',
            'content_category_id' => $category->id, 'body' => json_encode([
                'image_url' => 'https://example.com/web-content.jpg',
                'data' => ['body' => 'Texto web'],
            ]),
            'status' => 'publicado', 'published_at' => now(),
        ]);
        \App\Models\Microbusiness::create(['name' => 'Negocio desde web', 'latitude' => 4.7, 'longitude' => -74.0]);
        \App\Models\BusinessEntity::create(['name' => 'Entidad desde web']);

        $this->getJson('/api/mobile/categories')->assertOk()->assertJsonFragment(['nombre' => 'Categoría desde web']);
        $this->getJson('/api/mobile/contents')->assertOk()
            ->assertJsonFragment(['titulo' => 'Contenido desde web'])
            ->assertJsonFragment(['imagen' => 'https://example.com/web-content.jpg']);
        $this->getJson('/api/mobile/microbusinesses')->assertOk()->assertJsonFragment(['nombre' => 'Negocio desde web']);
        $this->getJson('/api/mobile/entities')->assertOk()->assertJsonFragment(['name' => 'Entidad desde web']);
    }

    public function test_firebase_identity_can_open_a_laravel_session(): void
    {
        User::factory()->create([
            'email' => 'nuevo@example.com',
            'firebase_uid' => null,
            'photo_url' => 'https://example.com/existing-avatar.jpg',
        ]);

        $firebase = Mockery::mock(FirebaseTokenService::class);
        $firebase->shouldReceive('verify')->once()->with('valid-firebase-token')->andReturn([
            'uid' => 'firebase-new-user',
            'email' => 'nuevo@example.com',
        ]);
        $this->app->instance(FirebaseTokenService::class, $firebase);

        $this->postJson('/api/auth/firebase', ['id_token' => 'valid-firebase-token'])
            ->assertOk()
            ->assertJsonPath('user.email', 'nuevo@example.com')
            ->assertJsonPath('user.photo_url', 'https://example.com/existing-avatar.jpg')
            ->assertJsonPath('user.has_microbusiness', false)
            ->assertJsonStructure(['token']);

        $this->assertDatabaseHas('users', [
            'email' => 'nuevo@example.com',
            'firebase_uid' => 'firebase-new-user',
        ]);
    }

    public function test_firebase_session_reports_when_required_microbusiness_is_registered(): void
    {
        $owner = User::factory()->create([
            'email' => 'propietario@example.com',
            'firebase_uid' => 'firebase-owner',
            'role' => Roles::MICROEMPRESARIO,
        ]);

        \App\Models\Microbusiness::create([
            'name' => 'Negocio obligatorio',
            'owner_id' => 'firebase-owner',
        ]);

        $firebase = Mockery::mock(FirebaseTokenService::class);
        $firebase->shouldReceive('verify')->once()->andReturn([
            'uid' => 'firebase-owner',
            'email' => 'propietario@example.com',
        ]);
        $this->app->instance(FirebaseTokenService::class, $firebase);

        $this->postJson('/api/auth/firebase', ['id_token' => 'owner-token'])
            ->assertOk()
            ->assertJsonPath('user.id', $owner->id)
            ->assertJsonPath('user.has_microbusiness', true);
    }

    public function test_mobile_profile_and_web_user_changes_share_laravel_state(): void
    {
        $this->postJson('/api/mobile/profile', [
            'name' => 'Administrador actualizado desde app',
            'photoUrl' => 'https://example.com/avatar.jpg',
        ])->assertOk()
            ->assertJsonPath('data.name', 'Administrador actualizado desde app')
            ->assertJsonPath('data.photoUrl', 'https://example.com/avatar.jpg');

        $managed = User::factory()->create([
            'firebase_uid' => 'firebase-managed-user',
            'role' => Roles::MICROEMPRESARIO,
            'is_active' => true,
        ]);

        $this->postJson('/api/mobile/users/firebase-managed-user', [
            'role' => Roles::DOCENTE,
            'isActive' => false,
        ])->assertOk()
            ->assertJsonPath('data.role', Roles::DOCENTE)
            ->assertJsonPath('data.isActive', false);

        $this->assertDatabaseHas('users', [
            'id' => $this->admin->id,
            'name' => 'Administrador actualizado desde app',
            'photo_url' => 'https://example.com/avatar.jpg',
        ]);
        $this->getJson('/api/auth/me')
            ->assertOk()
            ->assertJsonPath('photo_url', 'https://example.com/avatar.jpg');
        $this->assertDatabaseHas('users', [
            'id' => $managed->id,
            'role' => Roles::DOCENTE,
            'is_active' => false,
        ]);
    }

    public function test_mobile_profile_photo_is_stored_and_served_by_laravel(): void
    {
        Storage::fake('public');
        $png = base64_decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        );

        $response = $this->post('/api/mobile/profile/photo', [
            'photo' => UploadedFile::fake()->createWithContent('avatar.png', $png),
        ], ['Accept' => 'application/json']);

        $response->assertOk()
            ->assertJsonPath('data.photoUrl', route('api.profile-photo', $this->admin));

        $this->admin->refresh();
        $this->assertNotNull($this->admin->photo_path);
        Storage::disk('public')->assertExists($this->admin->photo_path);
        $this->get(route('api.profile-photo', $this->admin))->assertOk();
    }

    public function test_mobile_microbusiness_image_is_stored_and_served_by_laravel(): void
    {
        Storage::fake('public');
        $this->postJson('/api/mobile/microbusinesses', [
            'id' => 'mobile-business-with-image',
            'nombre' => 'Negocio con imagen',
            'descripcion' => 'Creado desde la aplicación',
            'categoria' => 'Servicios',
            'direccion' => 'Bogotá',
            'latitud' => 4.711,
            'longitud' => -74.0721,
            'propietarioId' => 'firebase-admin',
            'estado' => 'activo',
        ])->assertCreated();

        $png = base64_decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        );
        $business = \App\Models\Microbusiness::where('external_id', 'mobile-business-with-image')->firstOrFail();

        $this->post('/api/mobile/microbusinesses/mobile-business-with-image/image', [
            'image' => UploadedFile::fake()->createWithContent('negocio.png', $png),
        ], ['Accept' => 'application/json'])
            ->assertOk()
            ->assertJsonPath('data.imagen', route('api.microbusiness-image', $business));

        $business->refresh();
        $this->assertNotNull($business->image_path);
        Storage::disk('public')->assertExists($business->image_path);
        $this->get(route('api.microbusiness-image', $business))->assertOk();
    }

    public function test_dashboard_logs_are_persisted_and_read_from_laravel(): void
    {
        $this->postJson('/api/mobile/logs', [
            'accion' => 'Abrir dashboard real',
            'modulo' => 'dashboard',
            'origen' => 'mobile',
            'detalle' => 'Registro generado por la aplicación',
        ])->assertCreated()
            ->assertJsonPath('data.accion', 'Abrir dashboard real')
            ->assertJsonPath('data.modulo', 'dashboard');

        $this->assertDatabaseHas('audit_logs', [
            'user_id' => $this->admin->id,
            'action' => 'Abrir dashboard real',
            'module' => 'dashboard',
        ]);

        $this->getJson('/api/mobile/logs?module=dashboard')
            ->assertOk()
            ->assertJsonFragment([
                'accion' => 'Abrir dashboard real',
                'detalle' => 'Registro generado por la aplicación',
            ]);
    }

    public function test_mobile_ratings_and_favorites_are_persisted_in_laravel(): void
    {
        $this->postJson('/api/mobile/microbusinesses', [
            'id' => 'business-feedback-1',
            'nombre' => 'Negocio con interacción',
            'categoria' => 'Servicios',
            'latitud' => 4.711,
            'longitud' => -74.0721,
            'propietarioId' => 'firebase-admin',
            'estado' => 'activo',
        ])->assertCreated();

        $this->postJson('/api/mobile/microbusinesses/business-feedback-1/rate', [
            'rating' => 4,
        ])->assertOk()
            ->assertJsonPath('data.ratingPromedio', 4)
            ->assertJsonPath('data.totalCalificaciones', 1);

        $this->postJson('/api/mobile/microbusinesses/business-feedback-1/rate', [
            'rating' => 2,
        ])->assertOk()
            ->assertJsonPath('data.ratingPromedio', 3)
            ->assertJsonPath('data.totalCalificaciones', 2);

        $this->postJson('/api/mobile/microbusinesses/business-feedback-1/favorite')
            ->assertOk()
            ->assertJsonPath('data.favoritos.0', 'firebase-admin');

        $this->assertDatabaseHas('microbusinesses', [
            'external_id' => 'business-feedback-1',
            'average_rating' => 3,
            'ratings_count' => 2,
        ]);
    }
}
