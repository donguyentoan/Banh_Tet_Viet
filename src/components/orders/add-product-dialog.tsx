import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Plus } from "lucide-react";
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
import { useCreateProduct } from "@/hooks/use-orders";
import { PRODUCT_CATEGORIES } from "@/lib/constants";
import {
  productFormSchema,
  type ProductFormValues,
} from "@/lib/types";

const CATEGORY_ITEMS = {
  CHUNG: PRODUCT_CATEGORIES.CHUNG,
  TET: PRODUCT_CATEGORIES.TET,
};

interface AddProductDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onCreated?: () => void;
}

export function AddProductDialog({
  open,
  onOpenChange,
  onCreated,
}: AddProductDialogProps) {
  const createProduct = useCreateProduct();

  const form = useForm<ProductFormValues>({
    resolver: zodResolver(productFormSchema),
    defaultValues: {
      name: "",
      price: 0,
      category: "CHUNG",
      icon: "🍃",
      weight: "1.0 kg",
    },
    mode: "onChange",
  });

  const { register, handleSubmit, reset, setValue, watch, formState } = form;

  function handleClose() {
    reset({
      name: "",
      price: 0,
      category: "CHUNG",
      icon: "🍃",
      weight: "1.0 kg",
    });
    onOpenChange(false);
  }

  return (
    <Dialog open={open} onOpenChange={(next) => (next ? undefined : handleClose())}>
      <DialogContent className="max-h-[92vh] w-[calc(100%-2rem)] max-w-lg overflow-y-auto border-amber-300 sm:max-w-lg">
        <DialogHeader className="bg-gradient-to-r from-emerald-700 to-emerald-600 text-white">
          <DialogTitle className="flex items-center gap-2 text-lg font-bold">
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
                icon: values.icon.trim() || "🍃",
                weight: values.weight.trim() || "1.0 kg",
              },
              {
                onSuccess: (product) => {
                  toast.success(`Đã thêm loại bánh "${product.name}"`);
                  onCreated?.();
                  handleClose();
                },
                onError: (error) => toast.error(error.message),
              },
            );
          })}
          className="space-y-4"
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
              <Label htmlFor="product-icon" className="mb-1 text-xs font-semibold">
                Biểu Tượng
              </Label>
              <Input
                id="product-icon"
                placeholder="🍃"
                className="text-center text-lg"
                {...register("icon")}
              />
              {formState.errors.icon && (
                <p className="mt-1 text-xs text-red-600">
                  {String(formState.errors.icon.message)}
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
          </div>

          <DialogFooter>
            <Button type="button" variant="secondary" onClick={handleClose}>
              Hủy Bỏ
            </Button>
            <Button
              type="submit"
              disabled={createProduct.isPending}
              className="bg-emerald-600 font-bold text-white hover:bg-emerald-700"
            >
              {createProduct.isPending ? "Đang lưu..." : "Thêm Loại Bánh"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
