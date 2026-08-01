<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('business_conversations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('microbusiness_id')->constrained('microbusinesses')->cascadeOnDelete();
            $table->foreignId('customer_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('owner_user_id')->constrained('users')->cascadeOnDelete();
            $table->unsignedBigInteger('customer_last_read_message_id')->nullable();
            $table->unsignedBigInteger('owner_last_read_message_id')->nullable();
            $table->timestamps();

            $table->unique(['microbusiness_id', 'customer_id']);
            $table->index(['owner_user_id', 'updated_at']);
        });

        Schema::create('business_chat_messages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('conversation_id')->constrained('business_conversations')->cascadeOnDelete();
            $table->foreignId('sender_id')->constrained('users')->cascadeOnDelete();
            $table->string('sender_name');
            $table->text('text');
            $table->timestamp('sent_at');
            $table->timestamps();

            $table->index(['conversation_id', 'sent_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('business_chat_messages');
        Schema::dropIfExists('business_conversations');
    }
};
