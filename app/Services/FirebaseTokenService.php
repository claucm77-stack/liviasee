<?php

namespace App\Services;

use Kreait\Firebase\Auth;
use Kreait\Firebase\Factory;

class FirebaseTokenService
{
    private Auth $auth;

    public function __construct()
    {
        $this->auth = (new Factory())
            ->withServiceAccount(config('services.firebase.credentials'))
            ->createAuth();
    }

    /** @return array{uid: string, email: string} */
    public function verify(string $idToken): array
    {
        $token = $this->auth->verifyIdToken($idToken);

        return [
            'uid' => (string) $token->claims()->get('sub'),
            'email' => (string) $token->claims()->get('email'),
        ];
    }
}
