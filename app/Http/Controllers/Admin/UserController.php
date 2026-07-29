<?php

namespace App\Http\Controllers\Admin;

use App\Constants\Roles;
use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\FirebaseUserService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Log;
use Illuminate\View\View;
use Illuminate\Pagination\LengthAwarePaginator;
use Kreait\Firebase\Exception\AuthException;
use Kreait\Firebase\Exception\FirebaseException;
use Throwable;

class UserController extends Controller
{
    public function __construct(private readonly FirebaseUserService $firebaseUsers)
    {
    }

    public function index(Request $request): View
    {
        $search = (string) $request->query('search', '');
        $page = (int) $request->query('page', 1);

        try {
            $users = $this->firebaseUsers->paginateUsers($search, 10, max(1, $page));

            return view('admin.users.index', compact('users', 'search'));
        } catch (Throwable $e) {
            $users = new LengthAwarePaginator(
                [],
                0,
                10,
                max(1, $page),
                [
                    'path' => $request->url(),
                    'query' => $request->query(),
                ]
            );

            return view('admin.users.index', compact('users', 'search'))
                ->withErrors([
                    'firebase' => 'No se pudo obtener usuarios de Firebase: '.$e->getMessage(),
                ]);
        }
    }

    public function create(): View
    {
        return view('admin.users.form', [
            'user' => [
                'uid' => '',
                'name' => '',
                'email' => '',
                'role' => Roles::DEFAULT,
                'is_active' => true,
                'description' => '',
            ],
            'isEdit' => false,
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'email' => ['required', 'email', 'max:180', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'role' => ['required', 'in:'.implode(',', Roles::active())],
            'is_active' => ['nullable', 'boolean'],
            'description' => ['nullable', 'string', 'max:2000'],
        ]);

        $validated['is_active'] = $request->boolean('is_active');

        $user = User::create([
            'firebase_uid' => null,
            'name' => $validated['name'],
            'email' => $validated['email'],
            'password' => bcrypt($validated['password']),
            'role' => Roles::normalize($validated['role']),
            'is_active' => $validated['is_active'],
            'email_verified_at' => now(),
            'teacher_description' => trim((string) ($validated['description'] ?? '')),
        ]);

        $statusMessage = 'Usuario creado correctamente.';

        try {
            $firebaseUid = $this->firebaseUsers->createUser($validated);
            $user->update(['firebase_uid' => $firebaseUid]);
        } catch (AuthException|FirebaseException|Throwable $e) {
            Log::error('No se pudo sincronizar usuario nuevo con Firebase', [
                'email' => $validated['email'],
                'error' => $e->getMessage(),
            ]);

            $statusMessage = 'Usuario creado en backend, pero no se pudo sincronizar con Firebase.';
        }

        return redirect()
            ->route('admin.users.index')
            ->with('status', $statusMessage);
    }

    public function edit(string $user): View|RedirectResponse
    {
        $localUser = User::where('firebase_uid', $user)->first();

        if (!$localUser && ctype_digit($user)) {
            $localUser = User::find((int) $user);
        }

        if (!$localUser) {
            $localUser = User::where('email', $user)->first();
        }

        if ($localUser) {
            $resolvedUser = [
                'uid' => $localUser->firebase_uid ?: (string) $localUser->id,
                'name' => $localUser->name,
                'email' => $localUser->email,
                'role' => $localUser->role,
                'is_active' => (bool) $localUser->is_active,
                'description' => (string) ($localUser->teacher_description ?? ''),
            ];

            return view('admin.users.form', [
                'user' => $resolvedUser,
                'isEdit' => true,
            ]);
        }

        $firebaseUser = $this->firebaseUsers->getUserByUid($user);

        if ($firebaseUser) {
            return view('admin.users.form', [
                'user' => $firebaseUser,
                'isEdit' => true,
            ]);
        }

        return redirect()
            ->route('admin.users.index')
            ->with('status', 'Usuario no encontrado.');
    }

    public function update(Request $request, string $user): RedirectResponse
    {
        $localUser = User::where('firebase_uid', $user)->first();

        if (!$localUser && ctype_digit($user)) {
            $localUser = User::find((int) $user);
        }

        if (!$localUser) {
            $localUser = User::where('email', $request->input('email'))->first();
        }

        if (!$localUser) {
            return redirect()
                ->route('admin.users.index')
                ->with('status', 'Usuario no encontrado.');
        }

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'email' => ['required', 'email', 'max:180'],
            'password' => ['nullable', 'string', 'min:8', 'confirmed'],
            'role' => ['required', 'in:'.implode(',', Roles::active())],
            'is_active' => ['nullable', 'boolean'],
            'description' => ['nullable', 'string', 'max:2000'],
        ]);

        $validated['is_active'] = $request->boolean('is_active');

        $localUser->update([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'role' => Roles::normalize($validated['role']),
            'is_active' => $validated['is_active'],
            'teacher_description' => trim((string) ($validated['description'] ?? '')),
        ]);

        if (!empty($validated['password'])) {
            $localUser->password = bcrypt($validated['password']);
            $localUser->save();
        }

        $statusMessage = 'Usuario actualizado correctamente.';

        if (!empty($localUser->firebase_uid)) {
            try {
                $this->firebaseUsers->updateUser($localUser->firebase_uid, $validated);
            } catch (AuthException|FirebaseException|Throwable $e) {
                Log::error('No se pudo sincronizar actualización de usuario con Firebase', [
                    'user_id' => $localUser->id,
                    'firebase_uid' => $localUser->firebase_uid,
                    'error' => $e->getMessage(),
                ]);

                $statusMessage = 'Usuario actualizado en backend, pero no se pudo sincronizar con Firebase.';
            }
        } else {
            try {
                $firebaseUid = $this->firebaseUsers->createUser($validated);
                $localUser->update(['firebase_uid' => $firebaseUid]);
            } catch (AuthException|FirebaseException|Throwable $e) {
                Log::error('Usuario local sin firebase_uid y falló creación en Firebase durante update', [
                    'user_id' => $localUser->id,
                    'email' => $localUser->email,
                    'error' => $e->getMessage(),
                ]);

                $statusMessage = 'Usuario actualizado en backend, pero sigue pendiente sincronización con Firebase.';
            }
        }

        return redirect()
            ->route('admin.users.index')
            ->with('status', $statusMessage);
    }

    public function destroy(string $user): RedirectResponse
    {
        $localUser = User::where('firebase_uid', $user)->first();

        if (!$localUser && ctype_digit($user)) {
            $localUser = User::find((int) $user);
        }

        if (!$localUser) {
            $localUser = User::where('email', $user)->first();
        }

        if (!$localUser) {
            return redirect()
                ->route('admin.users.index')
                ->with('status', 'Usuario no encontrado.');
        }

        $currentUser = auth()->user();
        if ($currentUser && $currentUser->id === $localUser->id) {
            return redirect()
                ->route('admin.users.index')
                ->with('status', 'No puedes eliminar tu propio usuario administrador.');
        }

        if (empty($localUser->firebase_uid)) {
            $localUser->delete();

            return redirect()
                ->route('admin.users.index')
                ->with('status', 'Usuario eliminado correctamente.');
        }

        try {
            $this->firebaseUsers->deleteUser($localUser->firebase_uid);
            $localUser->delete();
        } catch (AuthException|FirebaseException|Throwable $e) {
            return redirect()
                ->route('admin.users.index')
                ->with('status', 'No se pudo eliminar el usuario en Firebase: '.$e->getMessage());
        }

        return redirect()
            ->route('admin.users.index')
            ->with('status', 'Usuario eliminado correctamente.');
    }
}
