from fastapi import APIRouter, Depends

from app.deps import require_admin
from app.models import User

router = APIRouter(prefix="/admin", tags=["yönetici"])


@router.get("/ping", summary="Yönetici kontrolü")
def ping(admin: User = Depends(require_admin)) -> dict[str, str]:
    """Yönetici yetkisini denemek için basit uç; kategori ve kullanıcı yönetimi bu bağımlılığı kullanacak."""
    return {"durum": "ok", "yonetici": admin.display_name}
