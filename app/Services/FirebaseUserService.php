<?php

namespace App\Services;

use App\Constants\Roles;
use App\Models\User;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Collection;
use Kreait\Firebase\Auth;
use Kreait\Firebase\Auth\UserRecord;
use Kreait\Firebase\Factory;
use Kreait\Firebase\Firestore;
use Kreait\Firebase\Exception\Auth\UserNotFound;
use Throwable;

class FirebaseUserService
{
    private Auth $auth;
    private ?Firestore $firestore = null;
    private array $localUserCacheByEmail = [];

    public function __construct()
    {
        $credentials = config('services.firebase.credentials');

        $factory = (new Factory())->withServiceAccount($credentials);
        $this->auth = $factory->createAuth();

        try {
            $this->firestore = $factory->createFirestore();
        } catch (Throwable $e) {
            $this->firestore = null;
        }
    }

    public function paginateUsers(string $search = '', int $perPage = 10, int $page = 1): LengthAwarePaginator
    {
        $this->localUserCacheByEmail = $this->loadLocalUsersByEmail();
        $allUsers = [];
        $batch = $this->auth->listUsers();

        /** @var UserRecord $user */
        foreach ($batch as $user) {
            $allUsers[] = $this->mapUser($user);
        }

        $collection = collect($allUsers);

        if ($search !== '') {
            $needle = mb_strtolower($search);
            $collection = $collection->filter(function (array $user) use ($needle) {
                $name = mb_strtolower((string) ($user['name'] ?? ''));
                $email = mb_strtolower((string) ($user['email'] ?? ''));
                return str_contains($name, $needle) || str_contains($email, $needle);
            })->values();
        }

        $total = $collection->count();
        $items = $collection->forPage($page, $perPage)->values()->all();

        return new LengthAwarePaginator(
            $items,
            $total,
            $perPage,
            $page,
            [
                'path' => request()->url(),
                'query' => request()->query(),
            ]
        );
    }

    public function getUserByUid(string $uid): ?array
    {
        try {
            $record = $this->auth->getUser($uid);
            return $this->mapUser($record);
        } catch (UserNotFound $e) {
            return null;
        }
    }

    public function createUser(array $payload): string
    {
        $created = $this->auth->createUser([
            'email' => $payload['email'],
            'emailVerified' => false,
            'password' => $payload['password'],
            'displayName' => $payload['name'],
            'disabled' => !((bool) ($payload['is_active'] ?? true)),
        ]);

        $uid = $created->uid;
        $this->upsertUserProfile($uid, [
            'name' => $payload['name'],
            'email' => $payload['email'],
            'role' => Roles::normalize((string) $payload['role']),
            'rol' => Roles::normalize((string) $payload['role']),
            'is_active' => (bool) ($payload['is_active'] ?? true),
            'description' => trim((string) ($payload['description'] ?? '')),
        ]);

        return $uid;
    }

    public function updateUser(string $uid, array $payload): void
    {
        $update = [
            'email' => $payload['email'],
            'displayName' => $payload['name'],
            'disabled' => !((bool) ($payload['is_active'] ?? true)),
        ];

        if (!empty($payload['password'])) {
            $update['password'] = $payload['password'];
        }

        $this->auth->updateUser($uid, $update);

        $this->upsertUserProfile($uid, [
            'name' => $payload['name'],
            'email' => $payload['email'],
            'role' => Roles::normalize((string) $payload['role']),
            'rol' => Roles::normalize((string) $payload['role']),
            'is_active' => (bool) ($payload['is_active'] ?? true),
            'description' => trim((string) ($payload['description'] ?? '')),
        ]);
    }

    public function deleteUser(string $uid): void
    {
        $this->auth->deleteUser($uid);

        if ($this->firestore !== null) {
            $this->firestore->database()->collection('users')->document($uid)->delete();
        }
    }

    private function mapUser(UserRecord $user): array
    {
        $profile = $this->getUserProfile($user->uid);
        $firebaseEmail = (string) ($user->email ?? '');
        $email = (string) ($profile['email'] ?? $firebaseEmail);

        $localUser = $this->resolveLocalUserByEmail($email);

        return [
            'uid' => $user->uid,
            'name' => (string) ($profile['name'] ?? $user->displayName ?? $localUser?->name ?? ''),
            'email' => $email,
            'role' => Roles::normalize((string) ($profile['role'] ?? $profile['rol'] ?? $localUser?->role ?? Roles::DEFAULT)),
            'is_active' => isset($profile['is_active'])
                ? (bool) $profile['is_active']
                : ($localUser ? (bool) $localUser->is_active : !$user->disabled),
            'description' => (string) ($localUser?->teacher_description ?? $profile['description'] ?? ''),
        ];
    }

    private function getUserProfile(string $uid): array
    {
        if ($this->firestore === null) {
            return [];
        }

        $snapshot = $this->firestore->database()
            ->collection('users')
            ->document($uid)
            ->snapshot();

        if (!$snapshot->exists()) {
            return [];
        }

        return (array) $snapshot->data();
    }

    private function upsertUserProfile(string $uid, array $data): void
    {
        if ($this->firestore === null) {
            return;
        }

        $this->firestore->database()
            ->collection('users')
            ->document($uid)
            ->set($data, ['merge' => true]);
    }

    private function loadLocalUsersByEmail(): array
    {
        return User::query()
            ->select(['id', 'name', 'email', 'role', 'is_active'])
            ->get()
            ->keyBy(fn (User $user) => mb_strtolower((string) $user->email))
            ->all();
    }

    private function resolveLocalUserByEmail(string $email): ?User
    {
        if ($email === '') {
            return null;
        }

        $key = mb_strtolower($email);

        /** @var User|null $resolved */
        $resolved = $this->localUserCacheByEmail[$key] ?? null;

        return $resolved;
    }
}
