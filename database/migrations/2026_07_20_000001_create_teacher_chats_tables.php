<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('teacher_conversations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('teacher_key');
            $table->string('teacher_name');
            $table->string('teacher_area')->nullable();
            $table->timestamps();

            $table->unique(['user_id', 'teacher_key']);
        });

        Schema::create('teacher_chat_messages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('conversation_id')->constrained('teacher_conversations')->cascadeOnDelete();
            $table->foreignId('sender_id')->constrained('users')->cascadeOnDelete();
            $table->string('sender_name');
            $table->text('text');
            $table->boolean('is_teacher')->default(false);
            $table->timestamp('sent_at');
            $table->timestamps();

            $table->index(['conversation_id', 'sent_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('teacher_chat_messages');
        Schema::dropIfExists('teacher_conversations');
    }
};
