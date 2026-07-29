<?php

namespace App\Http\Controllers\Api\Auth;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\User;
use App\Services\FirebaseTokenService;
use App\Constants\Roles;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Throwable;

/**
 * Main authentication controller handling login, logout, and session management.
 */
class AuthController extends Controller
{
    public function firebase(Request $request, FirebaseTokenService $firebase): JsonResponse
    {
        $validated = $request->validate(['id_token' => ['required', 'string']]);

        try {
            $identity = $firebase->verify($validated['id_token']);
        } catch (Throwable) {
            return response()->json(['message' => 'Token de Firebase inválido.'], 401);
        }

        if ($identity['email'] === '') {
            return response()->json(['message' => 'La cuenta Firebase no tiene correo.'], 422);
        }

        $user = User::query()
            ->where('firebase_uid', $identity['uid'])
            ->orWhere('email', $identity['email'])
            ->first();

        if ($user) {
            $user->update(['firebase_uid' => $identity['uid']]);
        } else {
            $user = User::query()->create([
                'name' => Str::before($identity['email'], '@'),
                'email' => $identity['email'],
                'password' => Hash::make(Str::random(48)),
                'firebase_uid' => $identity['uid'],
                'role' => Roles::DEFAULT,
                'is_active' => true,
                'email_verified_at' => now(),
            ]);
        }

        if (! $user->is_active) {
            return response()->json(['message' => 'La cuenta está desactivada.'], 403);
        }

        $token = $user->createToken('firebase-app', ['*'], now()->addHours(24));

        return response()->json([
            'message' => 'Sesión Firebase vinculada.',
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'role' => $user->role,
                'photo_url' => $user->photoUrl(),
                'role_display_name' => $user->getRoleDisplayName(),
                'is_active' => $user->is_active,
                'has_microbusiness' => $user->hasMicrobusiness(),
                'description' => (string) ($user->teacher_description ?? ''),
            ],
            'token' => $token->plainTextToken,
            'expires_at' => $token->accessToken->expires_at,
        ]);
    }

    /**
     * Login user and create token.
     * 
     * @param Request $request
     * @return JsonResponse
     */
    public function login(Request $request): JsonResponse
    {
        $request->validate([
            'email' => 'required|email',
            'password' => 'required|string|min:8',
        ]);

        $user = User::where('email', $request->email)->first();

        // Check if user exists
        if (!$user) {
            AuditLog::log(
                null,
                AuditLog::ACTION_LOGIN_FAILED,
                'Intento de login con email no registrado: ' . $request->email,
                AuditLog::MODULE_AUTH,
                $request->ip(),
                $request->userAgent(),
                ['email' => $request->email]
            );

            return response()->json([
                'message' => 'Credenciales inválidas',
            ], 401);
        }

        // Check if user is active
        if (!$user->is_active) {
            AuditLog::log(
                $user->id,
                AuditLog::ACTION_LOGIN_FAILED,
                'Intento de login en cuenta desactivada',
                AuditLog::MODULE_AUTH,
                $request->ip(),
                $request->userAgent()
            );

            return response()->json([
                'message' => 'La cuenta está desactivada. Contacte al administrador.',
            ], 403);
        }

        // Verify password
        if (!Hash::check($request->password, $user->password)) {
            AuditLog::log(
                $user->id,
                AuditLog::ACTION_LOGIN_FAILED,
                'Intento de login con contraseña incorrecta',
                AuditLog::MODULE_AUTH,
                $request->ip(),
                $request->userAgent()
            );

            return response()->json([
                'message' => 'Credenciales inválidas',
            ], 401);
        }

        // Create token with expiration
        $token = $user->createToken(
            'auth-token',
            ['*'],
            now()->addHours(config('sanctum.token_expiration_hours', 24))
        );

        // Log successful login
        AuditLog::log(
            $user->id,
            AuditLog::ACTION_LOGIN,
            'Usuario inició sesión exitosamente',
            AuditLog::MODULE_AUTH,
            $request->ip(),
            $request->userAgent(),
            ['token_id' => $token->accessToken->id]
        );

        return response()->json([
            'message' => 'Login exitoso',
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'role' => $user->role,
                'photo_url' => $user->photoUrl(),
                'role_display_name' => $user->getRoleDisplayName(),
                'has_microbusiness' => $user->hasMicrobusiness(),
                'description' => (string) ($user->teacher_description ?? ''),
            ],
            'token' => $token->plainTextToken,
            'expires_at' => $token->accessToken->expires_at,
        ]);
    }

    /**
     * Logout user and revoke current token.
     * 
     * @param Request $request
     * @return JsonResponse
     */
    public function logout(Request $request): JsonResponse
    {
        $user = $request->user();

        if ($user) {
            // Revoke all tokens or just current token
            $request->user()->currentAccessToken()->delete();

            AuditLog::log(
                $user->id,
                AuditLog::ACTION_LOGOUT,
                'Usuario cerró sesión',
                AuditLog::MODULE_AUTH,
                $request->ip(),
                $request->userAgent()
            );
        }

        return response()->json([
            'message' => 'Logout exitoso',
        ]);
    }

    /**
     * Get current authenticated user.
     * 
     * @param Request $request
     * @return JsonResponse
     */
    public function me(Request $request): JsonResponse
    {
        $user = $request->user();

        return response()->json([
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'role' => $user->role,
            'photo_url' => $user->photoUrl(),
            'role_display_name' => $user->getRoleDisplayName(),
            'is_active' => $user->is_active,
            'created_at' => $user->created_at,
            'has_microbusiness' => $user->hasMicrobusiness(),
            'description' => (string) ($user->teacher_description ?? ''),
        ]);
    }

    /**
     * Refresh token.
     * 
     * @param Request $request
     * @return JsonResponse
     */
    public function refresh(Request $request): JsonResponse
    {
        $user = $request->user();

        // Revoke current token
        $request->user()->currentAccessToken()->delete();

        // Create new token
        $newToken = $user->createToken(
            'auth-token',
            ['*'],
            now()->addHours(config('sanctum.token_expiration_hours', 24))
        );

        AuditLog::log(
            $user->id,
            AuditLog::ACTION_SESSION_CREATED,
            'Token refrescado',
            AuditLog::MODULE_AUTH,
            $request->ip(),
            $request->userAgent()
        );

        return response()->json([
            'message' => 'Token refrescado',
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'role' => $user->role,
                'photo_url' => $user->photoUrl(),
                'role_display_name' => $user->getRoleDisplayName(),
                'is_active' => $user->is_active,
                'created_at' => $user->created_at,
                'has_microbusiness' => $user->hasMicrobusiness(),
                'description' => (string) ($user->teacher_description ?? ''),
            ],
            'token' => $newToken->plainTextToken,
            'expires_at' => $newToken->accessToken->expires_at,
        ]);
    }
}
