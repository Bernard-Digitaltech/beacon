<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    /**
     * User Registration
     */
    public function register(Request $req)
    {
        $validated = $req->validate([
            'name'        => 'required|string|max:255',
            'email'       => 'required|email|unique:users,email',
            'password'    => 'required|string|min:6',
            'device_uuid' => 'nullable|string'
        ]);

        $user = User::create([
            'name'        => $validated['name'],
            'email'       => $validated['email'],
            'password'    => Hash::make($validated['password']),
            'device_uuid' => $validated['device_uuid'] ?? null,
        ]);

        return response()->json([
            'token' => $user->createToken('api_token')->plainTextToken,
            'user'  => $user
        ]);
    }

    /**
     * User Login
     */
    public function login(Request $req)
    {
        $user = User::where('email', $req->email)->first();

        if (!$user || !Hash::check($req->password, $user->password)) {
            return response()->json(['error' => 'Invalid credentials'], 401);
        }

        return response()->json([
            'token' => $user->createToken('api_token')->plainTextToken,
            'user'  => $user
        ]);
    }
}
