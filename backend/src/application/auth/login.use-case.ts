import { UnauthorizedError } from '../../domain/errors/domain-error.js';
import type { UserRepository } from '../../domain/ports/user-repository.js';
import type { TokenService } from '../../domain/ports/token-service.js';
import { verifyPassword } from '../../shared/password-hasher.js';
import { toUserView, type UserView } from './user-view.js';

// Hash valido sem senha conhecida: mantem o custo do scrypt no caminho "e-mail inexistente".
const DUMMY_HASH = 'scrypt$16384$8$1$00000000000000000000000000000000$00';

export interface LoginOutput {
  accessToken: string;
  tokenType: 'Bearer';
  expiresIn: number;
  user: UserView;
}

export class LoginUseCase {
  constructor(
    private readonly users: UserRepository,
    private readonly tokens: TokenService,
  ) {}

  async execute(input: { email: string; password: string }): Promise<LoginOutput> {
    const user = await this.users.findByEmail(input.email.toLowerCase());
    // Verifica mesmo sem usuario para o tempo de resposta nao revelar se o e-mail existe.
    const passwordOk = verifyPassword(input.password, user?.passwordHash ?? DUMMY_HASH);
    if (!user || !passwordOk || !user.active) throw new UnauthorizedError('Credenciais invalidas');

    const { token, expiresIn } = await this.tokens.issue({ userId: user.id, role: user.role });
    return { accessToken: token, tokenType: 'Bearer', expiresIn, user: toUserView(user) };
  }
}
