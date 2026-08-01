<?php

namespace Tests\Feature;

use App\Constants\Roles;
use App\Models\Microbusiness;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class BusinessChatApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_customer_and_owner_can_chat_and_receive_unread_alerts(): void
    {
        $owner = User::factory()->create([
            'firebase_uid' => 'owner-uid',
            'role' => Roles::MICROEMPRESARIO,
            'is_active' => true,
        ]);
        $customer = User::factory()->create([
            'firebase_uid' => 'customer-uid',
            'role' => Roles::MICROEMPRESARIO,
            'is_active' => true,
        ]);
        $business = Microbusiness::query()->create([
            'name' => 'Negocio comunitario',
            'external_id' => 'business-key',
            'owner_id' => $owner->firebase_uid,
        ]);

        Sanctum::actingAs($customer);
        $this->getJson('/api/mobile/microbusinesses')
            ->assertOk()
            ->assertJsonFragment(['nombre' => 'Negocio comunitario']);

        $this->postJson('/api/mobile/business-chats/business-key/messages', [
            'text' => 'Hola, quiero conocer tus productos.',
        ])->assertCreated()->assertJsonPath('data.senderId', 'customer-uid');

        Sanctum::actingAs($owner);
        $this->getJson('/api/mobile/business-chats')
            ->assertOk()
            ->assertJsonPath('data.0.businessId', 'business-key')
            ->assertJsonPath('data.0.customerId', 'customer-uid')
            ->assertJsonPath('data.0.unreadCount', 1);

        $this->getJson('/api/mobile/business-chats/business-key/messages?customer_id=customer-uid')
            ->assertOk()
            ->assertJsonCount(1, 'data');
        $this->getJson('/api/mobile/business-chats')->assertJsonPath('data.0.unreadCount', 0);

        $this->postJson('/api/mobile/business-chats/business-key/messages', [
            'customer_id' => 'customer-uid',
            'text' => 'Claro, con gusto te atendemos.',
        ])->assertCreated();

        Sanctum::actingAs($customer);
        $this->getJson('/api/mobile/business-chats')
            ->assertOk()
            ->assertJsonPath('data.0.unreadCount', 1);

        $this->assertDatabaseHas('business_conversations', [
            'microbusiness_id' => $business->id,
            'customer_id' => $customer->id,
            'owner_user_id' => $owner->id,
        ]);
        $this->assertDatabaseCount('business_chat_messages', 2);
    }

    public function test_other_customers_cannot_read_a_private_business_conversation(): void
    {
        $owner = User::factory()->create(['firebase_uid' => 'owner-private', 'is_active' => true]);
        $first = User::factory()->create(['firebase_uid' => 'first-customer', 'is_active' => true]);
        $second = User::factory()->create(['firebase_uid' => 'second-customer', 'is_active' => true]);
        Microbusiness::query()->create([
            'name' => 'Negocio privado',
            'external_id' => 'private-business',
            'owner_id' => $owner->firebase_uid,
        ]);

        Sanctum::actingAs($first);
        $this->postJson('/api/mobile/business-chats/private-business/messages', [
            'text' => 'Mensaje privado',
        ])->assertCreated();

        Sanctum::actingAs($second);
        $this->getJson('/api/mobile/business-chats/private-business/messages')
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }
}
