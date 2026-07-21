<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\ContentCategory;
use App\Services\FirestoreSyncService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class ContentCategoryController extends Controller
{
    public function __construct(private readonly FirestoreSyncService $firestore)
    {
    }

    public function index(): View
    {
        $categories = ContentCategory::query()
            ->orderBy('sort_order')
            ->orderBy('name')
            ->paginate(20);

        return view('admin.content-categories.index', compact('categories'));
    }

    public function create(): View
    {
        return view('admin.content-categories.create');
    }

    public function store(Request $request): RedirectResponse
    {
        $validated = $this->validateCategory($request);
        $category = ContentCategory::create([
            'name' => $validated['name'],
            'slug' => $this->slug($validated['name']),
            'description' => $validated['description'] ?? null,
            'image_path' => $this->storeImage($request),
            'sort_order' => $validated['sort_order'] ?? 0,
            'is_active' => $request->boolean('is_active', true),
        ]);

        $this->firestore->syncContentCategory($category);
        $this->audit('content_category_created', "Categoría creada: {$category->name}", $category);

        return redirect()->route('admin.content-categories.index')->with('status', 'Categoría creada correctamente.');
    }

    public function edit(ContentCategory $contentCategory): View
    {
        return view('admin.content-categories.edit', compact('contentCategory'));
    }

    public function update(Request $request, ContentCategory $contentCategory): RedirectResponse
    {
        $validated = $this->validateCategory($request, $contentCategory);
        $imagePath = $contentCategory->image_path;
        if ($request->hasFile('image')) {
            $this->deleteImage($imagePath);
            $imagePath = $this->storeImage($request);
        }

        $contentCategory->update([
            'name' => $validated['name'],
            'slug' => $this->slug($validated['name'], $contentCategory),
            'description' => $validated['description'] ?? null,
            'image_path' => $imagePath,
            'sort_order' => $validated['sort_order'] ?? 0,
            'is_active' => $request->boolean('is_active'),
        ]);

        $this->firestore->syncContentCategory($contentCategory);
        $contentCategory->contents()->cursor()->each(fn ($content) => $this->firestore->syncContent($content));
        $this->audit('content_category_updated', "Categoría actualizada: {$contentCategory->name}", $contentCategory);

        return redirect()->route('admin.content-categories.index')->with('status', 'Categoría actualizada correctamente.');
    }

    public function destroy(ContentCategory $contentCategory): RedirectResponse
    {
        if ($contentCategory->contents()->exists()) {
            return back()->withErrors(['category' => 'No puedes eliminar una categoría que tiene contenidos asociados. Desactívala si no debe mostrarse.']);
        }

        $this->firestore->deleteContentCategory($contentCategory);
        $this->deleteImage($contentCategory->image_path);
        $name = $contentCategory->name;
        $contentCategory->delete();
        $this->audit('content_category_deleted', "Categoría eliminada: {$name}");

        return redirect()->route('admin.content-categories.index')->with('status', 'Categoría eliminada correctamente.');
    }

    private function validateCategory(Request $request, ?ContentCategory $category = null): array
    {
        $rules = [
            'name' => ['required', 'string', 'max:120', Rule::unique('content_categories', 'name')->ignore($category?->id)],
            'description' => ['nullable', 'string', 'max:500'],
            'image' => ['nullable', 'image', 'max:4096'],
            'sort_order' => ['nullable', 'integer', 'min:0', 'max:9999'],
            'is_active' => ['nullable', 'boolean'],
        ];

        if ($category === null) {
            $rules['image'][] = 'required';
        }

        return $request->validate($rules);
    }

    private function slug(string $name, ?ContentCategory $category = null): string
    {
        $base = Str::slug($name) ?: Str::random(8);
        $slug = $base;
        $suffix = 2;
        while (ContentCategory::query()->where('slug', $slug)->when($category, fn ($query) => $query->whereKeyNot($category->id))->exists()) {
            $slug = "{$base}-{$suffix}";
            $suffix++;
        }
        return $slug;
    }

    private function storeImage(Request $request): ?string
    {
        return $request->hasFile('image') ? $request->file('image')->store('content-categories', 'public') : null;
    }

    private function deleteImage(?string $path): void
    {
        if ($path) {
            Storage::disk('public')->delete($path);
        }
    }

    private function audit(string $action, string $description, ?ContentCategory $category = null): void
    {
        AuditLog::log(auth()->id(), $action, $description, 'content_categories', request()->ip(), request()->userAgent(), $category ? ['category_id' => $category->id] : null);
    }
}
