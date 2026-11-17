import { clearZeroOnFocus } from "@/lib/utils";
import { useEffect, useMemo, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Plus, Sparkles } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useCreateProduct, useProducts } from "@/hooks/use-orders";
import { PRODUCT_CATEGORIES } from "@/lib/constants";
import {
  productFormSchema,
  type ProductFormValues,
  type Product,
} from "@/lib/types";
import { suggestProductCode } from "@/lib/product-code";

const CATEGORY_ITEMS = {
  CHUNG: PRODUCT_CATEGORIES.CHUNG,
  TET: PRODUCT_CATEGORIES.TET,
};

interface AddProductDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onCreated?: () => void;
}

/** Mảng rỗng ổn định - tránh tạo reference mới mỗi render */
const EMPTY_PRODUCTS: Product[] = [];

export function AddProductDialog({
  open,
  onOpenChange,
  onCreated,
}: AddProductDialogProps) {
  const createProduct = useCreateProduct();
  const { data: products } = useProducts();
  const existingProducts = products ?? EMPTY_PRODUCTS;

  const form = useForm<ProductFormValues>({
    resolver: zodResolver(productFormSchema),
    defaultValues: {
      name: "",
      price: 0,
      category: "CHUNG",
      code: "",
      icon: "🍃",
      weight: "1.0 kg",
    },
    mode: "onChange",
  });

  const { register, handleSubmit, reset, setValue, watch, formState } = form;

  const nameValue = watch("name");
  const categoryValue = watch("category");

  /** Mã gợi ý, tự sinh từ tên loại bánh + danh mục hiện có */
  const suggestedCode = useMemo(() => {
    if (!nameValue || nameValue.trim().length < 2) return "";
    return suggestProductCode(
      nameValue,
      categoryValue ?? "CHUNG",
      existingProducts,
    );
  }, [nameValue, categoryValue, existingProducts]);

  /**
   * Người dùng đã tự nhập mã thì giữ nguyên; chưa nhập thì lấy mã gợi ý.
   * Khi người dùng bấm nút "Tự sinh", mã sẽ được khoá lại (đánh dấu đã chọn).
   */
  const [isCodeManual, setIsCodeManual] = useState(false);

  useEffect(() => {
    if (isCodeManual) return;
    setValue("code", suggestedCode, { shouldValidate: false });
  }, [suggestedCode, isCodeManual, setValue]);

  function handleClose() {
    reset({
      name: "",
      price: 0,
      category: "CHUNG",
      code: "",
      icon: "🍃",
      weight: "1.0 kg",
    });
    setIsCodeManual(false);
    onOpenChange(false);
  }

  return (
    <Dialog open={open} onOpenChange={(next) => (next ? undefined : handleClose())}>
      <DialogContent className="max-h-[92vh] w-[calc(100%-1.5rem)] max-w-md overflow-y-auto overflow-x-hidden rounded-2xl border-red-200 p-0 shadow-xl sm:max-w-lg">
        <DialogHeader className="rounded-t-2xl bg-gradient-to-r from-red-700 to-red-800 px-5 py-4 text-white">
          <DialogTitle className="flex items-center gap-2 pr-8 text-base font-bold sm:text-lg">
            <Plus className="size-5 text-amber-300" />
            Thêm Loại Bánh Mới
          </DialogTitle>
          <DialogDescription className="sr-only">
            Đăng ký thêm một loại bánh vào danh mục.
          </DialogDescription>
        </DialogHeader>

        <form
          onSubmit={handleSubmit((values) => {
            createProduct.mutate(
              {
                name: values.name.trim(),
                price: Number(values.price) || 0,
                category: values.category,
                // Gửi mã đã sinh/nhập. Nếu bỏ trống, server sẽ tự sinh mã.
                code: values.code?.trim() ? values.code.trim() : undefined,
                icon: (values.category === "CHUNG" ? "/banh-chung.png" : "/banh-tet.png"),
                weight: values.weight.trim() || "1.0 kg",
              },
              {
                onSuccess: (product) => {
                  toast.success(
                    `Đã thêm loại bánh "${product.name}" (mã ${product.code ?? "—"})`,
                  );
                  onCreated?.();
                  handleClose();
                },
                onError: (error) => toast.error(error.message),
              },
            );
          })}
          className="space-y-4 px-5 py-5"
          noValidate
        >
          <div>
            <Label htmlFor="product-name" className="mb-1 text-xs font-semibold">
              Tên Loại Bánh <span className="text-red-500">*</span>
            </Label>
            <Input
              id="product-name"
              placeholder="VD: Bánh Chưng Nhân Đỗ Đỏ"
              {...register("name")}
            />
            {formState.errors.name && (
              <p className="mt-1 text-xs text-red-600">
                {String(formState.errors.name.message)}
              </p>
            )}
          </div>

          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div>
              <Label htmlFor="product-price" className="mb-1 text-xs font-semibold">
                Giá Bán / Cái (₫) <span className="text-red-500">*</span>
              </Label>
              <Input
                id="product-price"
                type="number"
                  onFocus={clearZeroOnFocus}
                min={0}
                step={10000}
                className="font-bold text-amber-700"
                {...register("price", { valueAsNumber: true })}
              />
              {formState.errors.price && (
                <p className="mt-1 text-xs text-red-600">
                  {String(formState.errors.price.message)}
                </p>
              )}
            </div>

            <div>
              <Label htmlFor="product-weight" className="mb-1 text-xs font-semibold">
                Khối Lượng
              </Label>
              <Input
                id="product-weight"
                placeholder="1.2 kg"
                {...register("weight")}
              />
              {formState.errors.weight && (
                <p className="mt-1 text-xs text-red-600">
                  {String(formState.errors.weight.message)}
                </p>
              )}
            </div>

            <div>
              <Label htmlFor="product-category" className="mb-1 text-xs font-semibold">
                Loại Bánh <span className="text-red-500">*</span>
              </Label>
              <Select
                items={CATEGORY_ITEMS}
                value={watch("category")}
                onValueChange={(value) =>
                  setValue("category", (value ?? "CHUNG") as "CHUNG" | "TET", {
                    shouldValidate: true,
                  })
                }
              >
                <SelectTrigger id="product-category" className="font-medium">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="CHUNG">{PRODUCT_CATEGORIES.CHUNG}</SelectItem>
                  <SelectItem value="TET">{PRODUCT_CATEGORIES.TET}</SelectItem>
                </SelectContent>
              </Select>
            </div>

            {/* Mã bánh - tự sinh từ tên, người dùng có thể sửa lại */}
            <div className="sm:col-span-2">
              <Label htmlFor="product-code" className="mb-1 text-xs font-semibold">
                Mã Bánh Ngắn{" "}
                <span className="font-normal text-gray-400">
                  (gõ nhanh trong tin nhắn)
                </span>
              </Label>
              <div className="flex items-center gap-2">
                <Input
                  id="product-code"
                  placeholder="VD: CM"
                  maxLength={6}
                  className="w-28 font-mono font-bold uppercase text-red-700"
                  {...register("code", {
                    onChange: (event) => {
                      setIsCodeManual(true);
                      event.target.value = event.target.value.toUpperCase();
                    },
                  })}
                />
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  className="gap-1.5 border-amber-300 bg-amber-50 text-amber-800 hover:bg-amber-100"
                  disabled={!suggestedCode}
                  onClick={() => {
                    setValue("code", suggestedCode);
                    setIsCodeManual(true);
                  }}
                  title="Sinh lại mã từ tên loại bánh"
                >
                  <Sparkles className="size-3.5" />
                  Tự sinh
                </Button>
                {suggestedCode && !isCodeManual && (
                  <span className="text-[11px] text-gray-500">
                    Đã tự sinh:{" "}
                    <strong className="font-mono text-red-700">
                      {suggestedCode}
                    </strong>
                  </span>
                )}
              </div>
              {formState.errors.code && (
                <p className="mt-1 text-xs text-red-600">
                  {String(formState.errors.code.message)}
                </p>
              )}
              <p className="mt-1 text-[11px] text-gray-400">
                Để trống nếu muốn hệ thống tự sinh mã. Mã tối đa 6 ký tự.
              </p>
            </div>
          </div>

          <DialogFooter className="-mx-5 -mb-5 mt-6 border-t border-gray-100 bg-gray-50 px-5 py-4">
            <Button type="button" variant="secondary" onClick={handleClose}>
              Hủy Bỏ
            </Button>
            <Button
              type="submit"
              disabled={createProduct.isPending}
              className="bg-red-700 font-bold text-white hover:bg-red-800"
            >
              {createProduct.isPending ? "Đang lưu..." : "Thêm Loại Bánh"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
