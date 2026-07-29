<?php

namespace App\Http\Controllers\Api\Auth;

use App\Constants\Roles;
use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;

/**
 * Controller for user registration.
 */
class RegisterController extends Controller
{
    /**
     * Register a new user.
     * 
     * @param Request $request
     * @return JsonResponse
     */
    public function register(Request $request): JsonResponse
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|max:255|unique:users,email',
            'password' => ['required', 'confirmed', Password::min(8)->mixedCase()->numbers()->symbols()],
        ]);

        // El registro publico siempre crea microempresarios. Los roles elevados
        // solo pueden asignarse desde la administracion protegida.
        $role = Roles::DEFAULT;

        // Create user
        $user = User::create([
            'name' => $request->name,
            'email' => $request->email,
            'password' => $request->password,
            'role' => $role,
            'is_active' => true, // Auto-activate for new registrations
        ]);

        // Create token for immediate login
        $token = $user->createToken('auth-token');

        // Log registration
        AuditLog::log(
            $user->id,
            AuditLog::ACTION_USER_CREATED,
            'Nuevo usuario registrado',
            AuditLog::MODULE_AUTH,
            $request->ip(),
            $request->userAgent(),
            ['role' => $role]
        );

        return response()->json([
            'message' => 'Usuario registrado exitosamente',
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'role' => $user->role,
                'photo_url' => $user->photoUrl(),
                'role_display_name' => $user->getRoleDisplayName(),
                'has_microbusiness' => false,
                'description' => '',
            ],
            'token' => $token->plainTextToken,
        ], 201);
    }
}
