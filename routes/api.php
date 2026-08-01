<?php

use App\Http\Controllers\Api\Auth\AuthController;
use App\Http\Controllers\Api\Auth\PasswordController;
use App\Http\Controllers\Api\Auth\RegisterController;
use App\Http\Controllers\Api\Auth\SessionController;
use App\Http\Controllers\Api\ContentController;
use App\Http\Controllers\Api\ContentCategoryController;
use App\Http\Controllers\Api\MicrobusinessFieldController;
use App\Http\Controllers\Api\MobileDataController;
use App\Http\Controllers\Api\TeacherChatController;
use App\Http\Controllers\Api\BusinessChatController;
use App\Http\Controllers\Api\ForumController;
use App\Http\Controllers\Api\UserController;
use App\Constants\Roles;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Public Routes (No Authentication Required)
|--------------------------------------------------------------------------
*/
Route::post('/auth/login', [AuthController::class, 'login']);
Route::post('/auth/firebase', [AuthController::class, 'firebase']);
Route::post('/auth/register', [RegisterController::class, 'register']);
Route::post('/auth/forgot', [PasswordController::class, 'forgot']);
Route::post('/auth/reset', [PasswordController::class, 'reset']);

/*
|--------------------------------------------------------------------------
| Protected Routes (Authentication Required)
|--------------------------------------------------------------------------
*/
Route::middleware(['auth:sanctum', 'active'])->group(function () {
    // Auth routes
    Route::get('/auth/me', [AuthController::class, 'me']);
    Route::post('/auth/logout', [AuthController::class, 'logout']);
    Route::post('/auth/refresh', [AuthController::class, 'refresh']);
    
    // Session management
    Route::get('/auth/sessions', [SessionController::class, 'index']);
    Route::delete('/auth/sessions/{tokenId}', [SessionController::class, 'destroy']);
    Route::post('/auth/sessions/revoke-all', [SessionController::class, 'revokeAll']);

    Route::prefix('mobile')->group(function () {
        Route::get('/users', [MobileDataController::class, 'users']);
        Route::get('/teachers', [MobileDataController::class, 'teachers']);
        Route::post('/users/{id}', [MobileDataController::class, 'updateUser']);
        Route::get('/logs', [MobileDataController::class, 'logs']);
        Route::post('/logs', [MobileDataController::class, 'saveLog']);
        Route::post('/profile', [MobileDataController::class, 'saveProfile']);
        Route::post('/profile/photo', [MobileDataController::class, 'saveProfilePhoto']);
        Route::get('/categories', [MobileDataController::class, 'categories']);
        Route::post('/categories', [MobileDataController::class, 'saveCategory']);
        Route::delete('/categories/{id}', [MobileDataController::class, 'deleteCategory']);
        Route::get('/alerts', [MobileDataController::class, 'alerts']);
        Route::post('/alerts', [MobileDataController::class, 'saveAlert']);
        Route::delete('/alerts/{alert}', [MobileDataController::class, 'deleteAlert']);
        Route::get('/contents', [MobileDataController::class, 'contents']);
        Route::post('/contents', [MobileDataController::class, 'saveContent']);
        Route::delete('/contents/{id}', [MobileDataController::class, 'deleteContent']);
        Route::get('/microbusinesses', [MobileDataController::class, 'microbusinesses']);
        Route::post('/microbusinesses', [MobileDataController::class, 'saveMicrobusiness']);
        Route::post('/microbusinesses/{id}/image', [MobileDataController::class, 'saveMicrobusinessImage']);
        Route::post('/microbusinesses/{id}/rate', [MobileDataController::class, 'rateMicrobusiness']);
        Route::post('/microbusinesses/{id}/favorite', [MobileDataController::class, 'toggleMicrobusinessFavorite']);
        Route::delete('/microbusinesses/{id}', [MobileDataController::class, 'deleteMicrobusiness']);
        Route::get('/entities', [MobileDataController::class, 'entities']);
        Route::post('/entities', [MobileDataController::class, 'saveEntity']);
        Route::delete('/entities/{id}', [MobileDataController::class, 'deleteEntity']);
        Route::get('/teacher-chats/{teacherKey}/messages', [TeacherChatController::class, 'index']);
        Route::post('/teacher-chats/{teacherKey}/messages', [TeacherChatController::class, 'store']);
        Route::get('/business-chats', [BusinessChatController::class, 'conversations']);
        Route::get('/business-chats/{businessKey}/messages', [BusinessChatController::class, 'index']);
        Route::post('/business-chats/{businessKey}/messages', [BusinessChatController::class, 'store']);
        Route::get('/forums', [ForumController::class, 'index']);
        Route::post('/forums', [ForumController::class, 'store']);
        Route::post('/forums/{forumTopic}/replies', [ForumController::class, 'reply']);
    });
    
    // Password management
    Route::post('/auth/password/change', [PasswordController::class, 'change']);
});

/*
|--------------------------------------------------------------------------
| Admin Routes (Admin Role Required)
|--------------------------------------------------------------------------
*/
Route::middleware(['auth:sanctum', 'role:' . Roles::ADMIN_TI . ',' . Roles::LEGACY_ADMIN])->group(function () {
    // User management
    Route::apiResource('users', UserController::class)->except(['create', 'edit']);
});

/*
|--------------------------------------------------------------------------
| Public API Routes (Public Access)
|--------------------------------------------------------------------------
*/
Route::get('/contents', [ContentController::class, 'index'])->name('api.contents.index');
Route::get('/content-categories', [ContentCategoryController::class, 'index'])->name('api.content-categories.index');
Route::get('/content-categories/{contentCategory}/image', [ContentCategoryController::class, 'image'])
    ->name('api.content-categories.image');
Route::get('/microbusiness-fields', [MicrobusinessFieldController::class, 'index'])->name('api.microbusiness-fields.index');
Route::get('/business-entities/{businessEntity}/image', [MobileDataController::class, 'entityImage'])
    ->name('api.business-entities.image');
Route::get('/profile-photo/{user}', [MobileDataController::class, 'profilePhoto'])
    ->name('api.profile-photo');
Route::get('/microbusinesses/{microbusiness}/image', [MobileDataController::class, 'microbusinessImage'])
    ->name('api.microbusiness-image');
